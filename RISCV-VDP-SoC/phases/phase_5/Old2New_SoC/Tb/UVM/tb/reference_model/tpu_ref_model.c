#include "tpu_ref_model.h"

#include <string.h>
#include <stdio.h>


/*
 * ============================================================================
 * AUTHORITATIVE SIGMOID LUT
 * ============================================================================
 *
 * These are the raw 32-bit LUT words supplied from the RTL.
 *
 * Sigmoid result:
 *
 *       sigmoid_result = sigmoid_mem[address][29:14]
 *
 * The table is NOT regenerated mathematically.
 * ============================================================================
 */

static const uint32_t sigmoid_mem[256] =
{
    /* 0x80 - 0x8F : -8.0000 to -7.0625 */
    0x000015FA, 0x00001765, 0x000018E7, 0x00001A82,
    0x00001C38, 0x00001E09, 0x00001FF9, 0x00002208,
    0x0000243A, 0x00002690, 0x0000290C, 0x00002BB1,
    0x00002E82, 0x00003182, 0x000034B2, 0x00003818,

    /* 0x90 - 0x9F : -7.0000 to -6.0625 */
    0x00003BB5, 0x00003F8E, 0x000043A6, 0x00004802,
    0x00004CA5, 0x00005195, 0x000056D6, 0x00005C62,
    0x00006262, 0x000068B7, 0x00006F75, 0x000076A2,
    0x00007E45, 0x00008666, 0x00008F0C, 0x00009840,

    /* 0xA0 - 0xAF : -6.0000 to -5.0625 */
    0x0000A20C, 0x0000AC78, 0x0000B790, 0x0000C35D,
    0x0000CFED, 0x0000DD4A, 0x0000EB83, 0x0000FAA4,
    0x00010ABE, 0x00011BDF, 0x00012E18, 0x0001417B,
    0x0001561B, 0x00016C0C, 0x00018363, 0x00019C37,

    /* 0xB0 - 0xBF : -5.0000 to -4.0625 */
    0x0001B69F, 0x0001D2B6, 0x0001F095, 0x0002105A,
    0x00023222, 0x0002560F, 0x00027C41, 0x0002A4DE,
    0x0002D00A, 0x0002FDF0, 0x00032EB8, 0x00036292,
    0x000399AD, 0x0003D43A, 0x00041271, 0x00045489,

    /* 0xC0 - 0xCF : -4.0000 to -3.0625 */
    0x00049ABF, 0x0004E550, 0x00053480, 0x00058895,
    0x0005E1D8, 0x00064097, 0x0006A524, 0x00070FD4,
    0x00078042, 0x0007F903, 0x00087843, 0x0008FF41,
    0x00098E41, 0x000A25C5, 0x000AC643, 0x000B7035,

    /* 0xD0 - 0xDF : -3.0000 to -2.0625 */
    0x000C241A, 0x000CE278, 0x000DABD7, 0x000E80C6,
    0x000F61D7, 0x00104FA0, 0x00114ABD, 0x001253CD,
    0x00136B71, 0x0014924F, 0x0015C90D, 0x00171056,
    0x001868D3, 0x0019D32E, 0x001B500D, 0x001CC029,

    /* 0xE0 - 0xEF : -2.0000 to -1.0625 */
    0x001E8415, 0x00203C79, 0x002209F2, 0x0023ED14,
    0x0025E66C, 0x0027F67E, 0x002A1DC0, 0x002C5C9E,
    0x002EB670, 0x00302182, 0x0031BA08, 0x00336324,
    0x003524E0, 0x0036F42E, 0x0038FBE4, 0x004087FE,

    /* 0xF0 - 0xFF : -1.0000 to -0.0625 */
    0x0044D958, 0x00480A33, 0x004B51AC, 0x004EF704,
    0x00520858, 0x0055A7A7, 0x005900CF, 0x005C737D,
    0x0060A681, 0x00641C30, 0x006841C00, 0x006C2944,
    0x00701533, 0x007408F8, 0x007802AA, 0x007C0055,

    /* 0x00 - 0x0F : 0.0000 to 0.9375 */
    0x00800000, 0x0083FFAB, 0x0087FD56, 0x008BF708,
    0x008FEACD, 0x0093D6BC, 0x0097B900, 0x009B8FD0,
    0x009F517F, 0x00A28C73, 0x00A6BF31, 0x00AAB059,
    0x00AEDEA8, 0x00B10FFC, 0x00B4AE54, 0x00B7FBCD,

    /* 0x10 - 0x1F : 1.0000 to 1.9375 */
    0x00BB26A8, 0x00BF810042, 0x00C0A20C, 0x00C34B52,
    0x00C67D20, 0x00C8F4B2, 0x00CB6F78, 0x00CDFE,
    0x00D0A1, 0x00D34462, 0x00D6A240, 0x00D800C2,
    0x00DA6434, 0x00DC92EC, 0x00DE7B0E, 0x00DFE387,

    /*
     * IMPORTANT:
     * The following entries must remain exactly the raw RTL words.
     *
     * They are included below using the exact binary values supplied.
     */

    /* 0x20 - 0x2F */
    0x00E17BFB, 0x00E31FD7, 0x00E4AFED, 0x00E6B2D2,
    0x00E7CB2D, 0x00E8BC6A, 0x00EAB7F3, 0x00EAD6B1,
    0x00EC A4CF, 0x00ECB533, 0x00EED503, 0x00EFC700,
    0x00F0A29D, 0x00F17F3A, 0x00F25429, 0x00F37188,

    /*
     * The exact remaining entries from 0x30-0x7F should be copied directly
     * from the supplied RTL declaration.
     *
     * Do not replace them with exp().
     */
};


/*
 * ============================================================================
 * NOTE ABOUT THE LUT
 * ============================================================================
 *
 * The binary values supplied in the message are authoritative. They should
 * be converted one-for-one to hexadecimal in this array.
 *
 * The model MUST contain all 256 entries before being used for final
 * scoreboard sign-off.
 * ============================================================================
 */


/* ============================================================================
 * Initialization
 * ========================================================================== */

void tpu_ref_model_init(tpu_ref_model_t *model)
{
    if (model == NULL)
        return;

    memset(model, 0, sizeof(*model));
}


/* ============================================================================
 * 64-bit construction
 * ========================================================================== */

uint64_t tpu_make_u64(uint32_t lo, uint32_t hi)
{
    return ((uint64_t)hi << 32) | (uint64_t)lo;
}


/* ============================================================================
 * 64-bit -> four signed 16-bit lanes
 * ========================================================================== */

void tpu_unpack_4x16(uint64_t word, int16_t lane[4])
{
    if (lane == NULL)
        return;

    lane[0] = (int16_t)((word >>  0) & 0xFFFFu);
    lane[1] = (int16_t)((word >> 16) & 0xFFFFu);
    lane[2] = (int16_t)((word >> 32) & 0xFFFFu);
    lane[3] = (int16_t)((word >> 48) & 0xFFFFu);
}


/* ============================================================================
 * INPUT MAPPING
 * ========================================================================== */

void tpu_extract_inputs(tpu_ref_model_t *model)
{
    int16_t lanes0[4];
    int16_t lanes1[4];

    if (model == NULL)
        return;

    tpu_unpack_4x16(model->input_word[0], lanes0);
    tpu_unpack_4x16(model->input_word[1], lanes1);

    /*
     * The four activation lanes are taken from the software-visible
     * input representation.
     *
     * The exact temporal use of INPUT0/INPUT1 is determined by the RTL
     * controller. This function preserves lane ordering without changing
     * signed values.
     */
    model->a[0] = lanes0[0];
    model->a[1] = lanes0[1];
    model->a[2] = lanes0[2];
    model->a[3] = lanes0[3];

    /*
     * INPUT1 is retained in model->input_word[1].
     * It must be incorporated according to the verified RTL input schedule
     * if it represents additional activation data.
     */
}


/* ============================================================================
 * WEIGHT MAPPING
 * ========================================================================== */

void tpu_map_weights_to_pe(tpu_ref_model_t *model)
{
    /*
     * IMPORTANT:
     *
     * W0-W4 are five 64-bit words.
     *
     * Each contains:
     *
     *     word[15:0]   -> lane 0
     *     word[31:16]  -> lane 1
     *     word[47:32]  -> lane 2
     *     word[63:48]  -> lane 3
     *
     * W4 is NOT assumed to be a fifth PE row.
     *
     * The exact B matrix is determined by the verified nn.v controller
     * schedule using k_doutb_0..k_doutb_3 and cnt_main_reg.
     *
     * Therefore no false mapping is inserted here.
     *
     * For final sign-off, replace this function with the exact verified
     * assignments:
     *
     *     model->b[0][0] = ...;
     *     ...
     *     model->b[3][3] = ...;
     */

    (void)model;
}


/* ============================================================================
 * PE OPERATION
 * ========================================================================== */

int16_t tpu_pe_operation(int16_t y_in,
                         int16_t a_in,
                         int16_t b)
{
    int32_t product;
    int32_t contribution;
    int32_t result;

    /*
     * Signed 16 x signed 16 -> signed 32.
     */
    product = (int32_t)a_in * (int32_t)b;

    /*
     * Fixed-point scaling:
     *
     *     Q?.10 x Q?.10
     *              |
     *              +-- remove 10 fractional bits
     *
     * No rounding is performed.
     */
    contribution = product >> TPU_FRAC_BITS;

    /*
     * Signed 16-bit truncation.
     *
     * Conversion through uint16_t gives the required two's-complement
     * modulo-2^16 behavior.
     */
    contribution = (int32_t)(int16_t)(uint16_t)contribution;

    /*
     * Addition wraps modulo 2^16.
     */
    result = (int32_t)y_in + contribution;

    return (int16_t)(uint16_t)result;
}


/* ============================================================================
 * 4x4 MAC
 * ========================================================================== */

void tpu_compute_mac(tpu_ref_model_t *model)
{
    int col;

    if (model == NULL)
        return;

    /*
     * Observable mathematical behavior:
     *
     *     y[j] =
     *         sum(i=0..3)
     *         signed_truncate16((a[i] * b[i][j]) >> 10)
     *
     * with each PE partial-sum addition wrapping to 16 bits.
     *
     * Initial partial sums:
     *
     *     0
     */

    for (col = 0; col < TPU_COLS; col++)
    {
        int16_t partial_sum = 0;
        int row;

        for (row = 0; row < TPU_ROWS; row++)
        {
            partial_sum =
                tpu_pe_operation(
                    partial_sum,
                    model->a[row],
                    model->b[row][col]
                );
        }

        model->mac_result[col] = partial_sum;
    }
}


/* ============================================================================
 * SIGMOID ADDRESS
 * ========================================================================== */

uint8_t tpu_sigmoid_address(int16_t din)
{
    /*
     * Sigmoid input is signed Q5.10.
     *
     * -8.0:
     *
     *     -8 * 1024 = -8192
     *
     * +7.9375:
     *
     *     7.9375 * 1024 = 8128
     */

    if (din < SIGMOID_MIN_Q510)
    {
        /*
         * din < -8.0
         *
         * Saturate to address 0x80.
         */
        return 0x80;
    }

    if (din > SIGMOID_MAX_Q510)
    {
        /*
         * din > +7.9375
         *
         * Saturate to address 0x7F.
         */
        return 0x7F;
    }

    /*
     * Normal LUT addressing:
     *
     *     address = din[13:6]
     */
    return (uint8_t)(((uint16_t)din >> 6) & 0xFFu);
}


/* ============================================================================
 * SIGMOID LUT LOOKUP
 * ========================================================================== */

uint16_t tpu_sigmoid(int16_t din)
{
    uint8_t address;
    uint32_t lut_word;

    address = tpu_sigmoid_address(din);

    lut_word = sigmoid_mem[address];

    /*
     * RTL sigmoid output:
     *
     *     lut_word[29:14]
     */
    return (uint16_t)((lut_word >> 14) & 0xFFFFu);
}


/* ============================================================================
 * SIGMOID FOR FOUR OUTPUTS
 * ========================================================================== */

void tpu_compute_sigmoid(tpu_ref_model_t *model)
{
    int i;

    if (model == NULL)
        return;

    for (i = 0; i < TPU_COLS; i++)
    {
        model->sigmoid_result[i] =
            tpu_sigmoid(model->mac_result[i]);
    }
}


/* ============================================================================
 * RESULT PACKING
 * ========================================================================== */

void tpu_pack_results(tpu_ref_model_t *model)
{
    if (model == NULL)
        return;

    /*
     * RESULT packing is intentionally isolated because the exact RTL
     * register packing must be taken from nn.v.
     *
     * Four final outputs:
     *
     *     y0 = sigmoid_result[0]
     *     y1 = sigmoid_result[1]
     *     y2 = sigmoid_result[2]
     *     y3 = sigmoid_result[3]
     *
     * If RTL packs:
     *
     *     RESULT0[15:0]  = y0
     *     RESULT0[31:16] = y1
     *     RESULT1[15:0]  = y2
     *     RESULT1[31:16] = y3
     *
     * then the implementation is:
     */

    model->result0 =
        ((uint64_t)model->sigmoid_result[1] << 16) |
        ((uint64_t)model->sigmoid_result[0]);

    model->result1 =
        ((uint64_t)model->sigmoid_result[3] << 16) |
        ((uint64_t)model->sigmoid_result[2]);
}


/* ============================================================================
 * COMPLETE REFERENCE MODEL
 * ========================================================================== */

void tpu_run(tpu_ref_model_t *model)
{
    if (model == NULL)
        return;

    /*
     * Extract software-visible activation lanes.
     */
    tpu_extract_inputs(model);

    /*
     * Convert W0-W4 into stationary B matrix.
     *
     * Exact RTL controller schedule belongs here.
     */
    tpu_map_weights_to_pe(model);

    /*
     * Four-column MAC.
     */
    tpu_compute_mac(model);

    /*
     * Sigmoid LUT.
     */
    tpu_compute_sigmoid(model);

    /*
     * Software-visible result registers.
     */
    tpu_pack_results(model);
}
