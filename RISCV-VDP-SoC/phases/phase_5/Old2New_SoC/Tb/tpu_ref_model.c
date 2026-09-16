#include "tpu_ref_model.h"
#include <string.h>

/*
 * Convert a 16-bit bit-pattern to int16_t without relying on implementation
 * details of signed right shifts or aliasing.
 */
static int16_t bits_to_i16(uint16_t x)
{
    if (x & 0x8000u)
        return (int16_t)((int32_t)x - 65536);
    return (int16_t)x;
}

static uint16_t i16_to_bits(int16_t x)
{
    return (uint16_t)x;
}

static void unpack_word(uint64_t word, int16_t lane[4])
{
    lane[0] = bits_to_i16((uint16_t)(word >> 0));
    lane[1] = bits_to_i16((uint16_t)(word >> 16));
    lane[2] = bits_to_i16((uint16_t)(word >> 32));
    lane[3] = bits_to_i16((uint16_t)(word >> 48));
}

/*
 * This is intentionally the PE arithmetic, not a floating-point MAC:
 *
 *   product = signed(a) * signed(b)          // 32-bit
 *   scaled  = product[25:10]                 // arithmetic fixed-point slice
 *   y_out   = 16-bit(y_in + scaled)           // two's-complement wrap
 *
 * The explicit arithmetic shift followed by int16_t conversion models the
 * 16-bit Verilog result width and avoids saturation.
 */
int16_t tpu_pe_mac(int16_t a, int16_t b, int16_t y)
{
    int32_t product = (int32_t)a * (int32_t)b;
    int32_t scaled = product >> TPU_Q_FRAC;
    int32_t sum = (int32_t)y + scaled;
    return (int16_t)(uint16_t)sum;
}

/*
 * sigmoid.v:
 *
 *   if din[15:13] is neither 000 nor 111:
 *       addr = din[15] ? 0x80 : 0x7f
 *   else:
 *       addr = din[13:6]
 *
 * The table already contains mem[addr][29:14], so no floating-point
 * calculation is performed here.
 */
uint16_t tpu_sigmoid(uint16_t din)
{
    uint16_t top = (uint16_t)((din >> 13) & 0x7u);
    uint8_t addr;

    if (top != 0u && top != 7u)
        addr = (din & 0x8000u) ? 0x80u : 0x7fu;
    else
        addr = (uint8_t)((din >> 6) & 0xffu);

    return sigmoid_lut[addr];
}

void tpu_input_clear(tpu_input_t *in)
{
    memset(in, 0, sizeof(*in));
}

/*
 * Compute one four-lane systolic result for one moving word.
 *
 * The stationary array is arranged as:
 *
 *       b00 b01 b02 b03
 *       b10 b11 b12 b13
 *       b20 b21 b22 b23
 *       b30 b31 b32 b33
 *
 * The moving lanes a0..a3 are injected into the four systolic rows.
 * For the mathematical golden model, the completed column results are:
 *
 *       y[col] = sum(row=0..3) a[row] * b[row][col]
 *
 * with the exact PE fixed-point operation applied at every accumulation.
 */
static void systolic_word(const int16_t a[4],
                          const int16_t b[4][4],
                          int16_t y[4])
{
    int col, row;

    for (col = 0; col < 4; ++col) {
        y[col] = 0;
        for (row = 0; row < 4; ++row)
            y[col] = tpu_pe_mac(a[row], b[row][col], y[col]);
    }
}

/*
 * The specification's two valid windows are represented as two passes:
 *
 *   pass 0: wb[0], wb[1], wb[2]
 *   pass 1: wb[3], wb[4]
 *
 * Stationary values are:
 *
 *   row 0 = k[0]
 *   row 1 = k[1]
 *   row 2 = 1.0 in Q6.10
 *   row 3 = 1.0 in Q6.10
 *
 * After pass 0, sigmoid feedback replaces rows 0..2. Row 3 remains 1.0.
 * Pass 1 then produces the final four sigmoid values.
 */
void tpu_run(const tpu_input_t *in, tpu_state_t *state)
{
    int16_t k0[4], k1[4];
    int16_t y[4];
    int16_t pass0[4];
    int16_t pass1[4];
    int i, j;

    memset(state, 0, sizeof(*state));

    unpack_word(in->k[0], k0);
    unpack_word(in->k[1], k1);

    for (j = 0; j < 4; ++j) {
        state->b[0][j] = k0[j];
        state->b[1][j] = k1[j];
        state->b[2][j] = TPU_ONE_Q;
        state->b[3][j] = TPU_ONE_Q;
    }

    /*
     * First moving window. The three words are consumed in order.
     * The result is accumulated across the window using the same PE
     * operation as the hardware.
     */
    for (j = 0; j < 4; ++j)
        pass0[j] = 0;

    for (i = 0; i < 3; ++i) {
        unpack_word(in->wb[i], state->a);
        systolic_word(state->a, state->b, y);
        for (j = 0; j < 4; ++j)
            pass0[j] = (int16_t)(uint16_t)((int32_t)pass0[j] + y[j]);
    }

    for (j = 0; j < 4; ++j)
        pass0[j] = tpu_sigmoid(i16_to_bits(pass0[j]));

    /*
     * Sigmoid feedback:
     *   row 0 <- s0..s3
     *   row 1 <- s0..s3
     *   row 2 <- s0..s3
     *   row 3 stays at 1.0
     *
     * Keep the values as 16-bit bit-patterns, exactly as the RTL registers do.
     */
    for (j = 0; j < 4; ++j) {
        state->b[0][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[1][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[2][j] = bits_to_i16((uint16_t)pass0[j]);
        state->b[3][j] = TPU_ONE_Q;
    }

    /*
     * Second moving window. The two remaining wb words are consumed in
     * order. The final result is what is written to output BRAM.
     */
    for (j = 0; j < 4; ++j)
        pass1[j] = 0;

    for (i = 3; i < 5; ++i) {
        unpack_word(in->wb[i], state->a);
        systolic_word(state->a, state->b, y);
        for (j = 0; j < 4; ++j)
            pass1[j] = (int16_t)(uint16_t)((int32_t)pass1[j] + y[j]);
    }

    for (j = 0; j < 4; ++j) {
        state->sigmoid[j] = tpu_sigmoid(i16_to_bits(pass1[j]));
    }

    state->result0 =
        ((uint64_t)state->sigmoid[0] << 0)  |
        ((uint64_t)state->sigmoid[1] << 16) |
        ((uint64_t)state->sigmoid[2] << 32) |
        ((uint64_t)state->sigmoid[3] << 48);

    /*
     * The RTL output BRAM has two 64-bit addresses. The first contains the
     * four final sigmoid lanes; the second is the next output beat. This
     * model exposes both beats explicitly and leaves result1 zero unless
     * a caller extends the specification with a second output vector.
     */
    state->result1 = 0;
}

void tpu_reference(const uint64_t axi_words[7],
                   uint64_t *result0,
                   uint64_t *result1)
{
    tpu_input_t in;
    tpu_state_t state;

    memcpy(in.wb, &axi_words[0], sizeof(in.wb));
    memcpy(in.k,  &axi_words[5], sizeof(in.k));

    tpu_run(&in, &state);

    if (result0)
        *result0 = state.result0;
    if (result1)
        *result1 = state.result1;
}
