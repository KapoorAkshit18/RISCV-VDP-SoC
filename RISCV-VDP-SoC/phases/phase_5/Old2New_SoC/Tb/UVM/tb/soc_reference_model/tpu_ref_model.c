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
int16_t tpu_pe_mac(int16_t a, int16_t b, int16_t y){
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
 * Compute one four-lane systolic result for one moving word.
 *
 * y[col] = sum(row = 0..3) a[row] * b[row][col]
 *
 * Each accumulation uses the PE fixed-point operation.
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
 * Execute the behavioral TPU reference model.
 *
 * First moving-word schedule:
 *     wb[0], wb[1], wb[2], wb[2]
 *
 * Second moving-word schedule:
 *     wb[3], wb[4], wb[4], wb[4]
 */
void tpu_run(const tpu_input_t *in, tpu_state_t *state)
{
    int16_t k0[4];
    int16_t k1[4];

    int16_t y[4];
    int16_t pass0[4];
    int16_t pass1[4];

    int j;
    int cycle;

    static const int first_pass_wb[4] = {
        0, 1, 2, 2
    };

    static const int second_pass_wb[4] = {
        3, 4, 4, 4
    };

    memset(state, 0, sizeof(*state));

    /*
     * Unpack stationary input words.
     */
    unpack_word(in->k[0], k0);
    unpack_word(in->k[1], k1);

    /*
     * Initial stationary array.
     *
     * Row 0 = k[0]
     * Row 1 = k[1]
     * Row 2 = 1.0 in Q6.10
     * Row 3 = 1.0 in Q6.10
     */
    for (j = 0; j < 4; ++j) {
        state->b[0][j] = k0[j];
        state->b[1][j] = k1[j];
        state->b[2][j] = TPU_ONE_Q;
        state->b[3][j] = TPU_ONE_Q;
    }

    /*
     * First pass accumulation.
     */
    for (j = 0; j < 4; ++j) {
        pass0[j] = 0;
    }

    for (cycle = 0; cycle < 4; ++cycle) {
        int wb_index;

        wb_index = first_pass_wb[cycle];

        unpack_word(in->wb[wb_index], state->a);
        systolic_word(state->a, state->b, y);

        for (j = 0; j < 4; ++j) {
            pass0[j] = (int16_t)(uint16_t)(
                (int32_t)pass0[j] + (int32_t)y[j]
            );
        }
    }

    /*
     * Apply sigmoid after the first pass.
     */
    for (j = 0; j < 4; ++j) {
        pass0[j] = (int16_t)(
            uint16_t)tpu_sigmoid(i16_to_bits(pass0[j])
        );
    }

    /*
     * Sigmoid feedback.
     *
     * Rows 0, 1, and 2 receive the first-pass sigmoid values.
     * Row 3 remains equal to TPU_ONE_Q.
     */
    for (j = 0; j < 4; ++j) {
        state->b[0][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[1][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[2][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[3][j] = TPU_ONE_Q;
    }

    /*
     * Second pass accumulation.
     */
    for (j = 0; j < 4; ++j) {
        pass1[j] = 0;
    }

    for (cycle = 0; cycle < 4; ++cycle) {
        int wb_index;

        wb_index = second_pass_wb[cycle];

        unpack_word(in->wb[wb_index], state->a);
        systolic_word(state->a, state->b, y);

        for (j = 0; j < 4; ++j) {
            pass1[j] = (int16_t)(uint16_t)(
                (int32_t)pass1[j] + (int32_t)y[j]
            );
        }
    }

    /*
     * Apply sigmoid after the second pass.
     */
    for (j = 0; j < 4; ++j) {
        state->sigmoid[j] =
            tpu_sigmoid(i16_to_bits(pass1[j]));
    }

    /*
     * Pack final sigmoid values:
     *
     * bits [15:0]  = s0
     * bits [31:16] = s1
     * bits [47:32] = s2
     * bits [63:48] = s3
     */
    state->result0 =
          ((uint64_t)state->sigmoid[0] << 0)
        | ((uint64_t)state->sigmoid[1] << 16)
        | ((uint64_t)state->sigmoid[2] << 32)
        | ((uint64_t)state->sigmoid[3] << 48);

    /*
     * The specification currently does not define the second
     * output word.
     */
    state->result1 = 0;
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