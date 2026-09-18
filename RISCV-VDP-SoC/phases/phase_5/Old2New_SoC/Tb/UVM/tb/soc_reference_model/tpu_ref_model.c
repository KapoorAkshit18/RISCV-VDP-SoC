#include "tpu_ref_model.h"

#include <stdint.h>
#include <string.h>

/*
 * Convert a 16-bit bit-pattern to int16_t.
 */
static int16_t bits_to_i16(uint16_t x)
{
    if (x & 0x8000u)
        return (int16_t)((int32_t)x - 65536);

    return (int16_t)x;
}

/*
 * Convert int16_t to its 16-bit bit-pattern.
 */
static uint16_t i16_to_bits(int16_t x)
{
    return (uint16_t)x;
}

/*
 * Unpack a 64-bit word into four 16-bit little-endian lanes.
 */
static void unpack_word(uint64_t word, int16_t lane[4])
{
    lane[0] = bits_to_i16((uint16_t)(word >> 0));
    lane[1] = bits_to_i16((uint16_t)(word >> 16));
    lane[2] = bits_to_i16((uint16_t)(word >> 32));
    lane[3] = bits_to_i16((uint16_t)(word >> 48));
}

/*
 * PE arithmetic:
 *
 * product = signed(a) * signed(b)
 * scaled  = product >> TPU_Q_FRAC
 * y_out   = 16-bit(y + scaled), with two's-complement wrap
 */
int16_t tpu_pe_mac(int16_t a, int16_t b, int16_t y)
{
    int32_t product;
    int32_t scaled;
    int32_t sum;

    product = (int32_t)a * (int32_t)b;
    scaled = product >> TPU_Q_FRAC;
    sum = (int32_t)y + scaled;

    return (int16_t)(uint16_t)sum;
}

/*
 * Sigmoid lookup.
 */
uint16_t tpu_sigmoid(uint16_t din)
{
    uint16_t top;
    uint8_t addr;

    top = (uint16_t)((din >> 13) & 0x7u);

    if (top != 0u && top != 7u) {
        addr = (din & 0x8000u) ? 0x80u : 0x7fu;
    } else {
        addr = (uint8_t)((din >> 6) & 0xffu);
    }

    return sigmoid_lut[addr];
}

/*
 * Clear TPU input structure.
 */
void tpu_input_clear(tpu_input_t *in)
{
    memset(in, 0, sizeof(*in));
}

/*
 * One 4x4 systolic matrix-vector product for a SINGLE moving word.
 *
 * y[col] = sum(row = 0..3) a[row] * b[row][col]
 *
 * This is the full contribution of ONE weight word against the
 * current stationary matrix -- it is NOT accumulated with any
 * other weight word's contribution. Confirmed from systolic.v /
 * nn.v cycle tracing: each weight word entering the array produces
 * its own independent dot-product-then-sigmoid result; results from
 * different weight words are never summed together.
 */
static void systolic_word(const int16_t a[4],
                           const int16_t b[4][4],
                           int16_t y[4])
{
    int col;
    int row;

    for (col = 0; col < 4; ++col) {
        y[col] = 0;

        for (row = 0; row < 4; ++row) {
            y[col] = tpu_pe_mac(a[row], b[row][col], y[col]);
        }
    }
}

/*
 * Run one weight word through the array against the given
 * stationary matrix and apply sigmoid, lane by lane.
 */
static void run_word(const tpu_input_t *in,
                      int wb_index,
                      const int16_t b[4][4],
                      uint16_t sig_out[4])
{
    int16_t a[4];
    int16_t y[4];
    int j;

    unpack_word(in->wb[wb_index], a);
    systolic_word(a, b, y);

    for (j = 0; j < 4; ++j) {
        sig_out[j] = tpu_sigmoid(i16_to_bits(y[j]));
    }
}

/*
 * Execute the behavioral TPU reference model.
 *
 * Architecture (derived from systolic.v pipeline tracing against
 * nn.v's cnt_main_reg schedule -- see debugging notes):
 *
 *   Pass 1 stationary matrix:
 *       row0 = input0, row1 = input1, row2 = 1.0 (Q6.10), row3 = 0
 *       (row3 is 0, NOT 1.0 -- b30_reg only becomes bias starting
 *        cnt=17, i.e. after pass 1 has already completed)
 *
 *   Pass 1: weight0, weight1, weight2 each independently multiply
 *   against the pass-1 matrix and are independently sigmoided.
 *   These three per-weight sigmoid results feed rows 0, 1, 2 of the
 *   pass-2 matrix (NOT summed together, NOT broadcast identically).
 *
 *   Pass 2 stationary matrix:
 *       row0 = sigmoid(weight0 . pass1_matrix)
 *       row1 = sigmoid(weight1 . pass1_matrix)
 *       row2 = sigmoid(weight2 . pass1_matrix)
 *       row3 = 1.0 (Q6.10)
 *
 *   Pass 2: weight3 and weight4 each independently multiply against
 *   the pass-2 matrix and are independently sigmoided.
 *       RESULT0 = sigmoid(weight3 . pass2_matrix)
 *       RESULT1 = sigmoid(weight4 . pass2_matrix)
 */
void tpu_run(const tpu_input_t *in, tpu_state_t *state)
{
    int16_t k0[4];
    int16_t k1[4];

    uint16_t fb0[4];
    uint16_t fb1[4];
    uint16_t fb2[4];

    uint16_t result0_lanes[4];
    uint16_t result1_lanes[4];

    int j;

    memset(state, 0, sizeof(*state));

    /*
     * Unpack stationary input words.
     */
    unpack_word(in->k[0], k0);
    unpack_word(in->k[1], k1);

    /*
     * Pass-1 stationary matrix.
     */
    for (j = 0; j < 4; ++j) {
        state->b[0][j] = k0[j];
        state->b[1][j] = k1[j];
        state->b[2][j] = TPU_ONE_Q;
        state->b[3][j] = 0;
    }

    /*
     * Pass 1: three independent weight x matrix products, each
     * individually sigmoided.
     */
    run_word(in, 0, state->b, fb0);
    run_word(in, 1, state->b, fb1);
    run_word(in, 2, state->b, fb2);

    /*
     * Pass-2 stationary matrix: rows 0-2 = the three independent
     * pass-1 sigmoid results, row3 = bias.
     */
    for (j = 0; j < 4; ++j) {
        state->b[0][j] = bits_to_i16(fb0[j]);
        state->b[1][j] = bits_to_i16(fb1[j]);
        state->b[2][j] = bits_to_i16(fb2[j]);
        state->b[3][j] = TPU_ONE_Q;
    }

    /*
     * Pass 2: weight3 -> RESULT0, weight4 -> RESULT1, each an
     * independent weight x matrix product, independently sigmoided.
     */
    run_word(in, 3, state->b, result0_lanes);
    run_word(in, 4, state->b, result1_lanes);

    for (j = 0; j < 4; ++j) {
        state->sigmoid[j] = result0_lanes[j];
    }

    /*
     * Pack final sigmoid values:
     *
     * bits [15:0]  = lane 0
     * bits [31:16] = lane 1
     * bits [47:32] = lane 2
     * bits [63:48] = lane 3
     */
    state->result0 =
          ((uint64_t)result0_lanes[0] << 0)
        | ((uint64_t)result0_lanes[1] << 16)
        | ((uint64_t)result0_lanes[2] << 32)
        | ((uint64_t)result0_lanes[3] << 48);

    state->result1 =
          ((uint64_t)result1_lanes[0] << 0)
        | ((uint64_t)result1_lanes[1] << 16)
        | ((uint64_t)result1_lanes[2] << 32)
        | ((uint64_t)result1_lanes[3] << 48);
}

/*
 * Top-level reference-model wrapper.
 */
void tpu_reference(const uint64_t axi_words[7],
                    uint64_t *result0,
                    uint64_t *result1)
{
    tpu_input_t in;
    tpu_state_t state;

    memcpy(in.wb, &axi_words[0], sizeof(in.wb));
    memcpy(in.k, &axi_words[5], sizeof(in.k));

    tpu_run(&in, &state);

    if (result0 != NULL) {
        *result0 = state.result0;
    }

    if (result1 != NULL) {
        *result1 = state.result1;
    }
}