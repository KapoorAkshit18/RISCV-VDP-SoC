#ifndef TPU_REF_MODEL_H
#define TPU_REF_MODEL_H

/*
 * ============================================================================
 * RISC-V SoC - Lightweight TPU
 * Bit-Accurate C Golden Reference Model
 * ============================================================================
 *
 * Observable TPU behavior:
 *
 *   1. Five 64-bit weight words: W0-W4
 *   2. Two 64-bit input words: INPUT0, INPUT1
 *   3. Four-by-four PE computation
 *   4. Signed 16-bit operands
 *   5. Signed 32-bit multiplication
 *   6. Fixed-point scaling by 2^10
 *   7. 16-bit truncation
 *   8. 16-bit modulo/wrap-around addition
 *   9. Sigmoid LUT
 *  10. Sigmoid input is signed Q5.10
 *
 * The model intentionally models observable numerical behavior rather than
 * reproducing the RTL microarchitecture.
 * ============================================================================
 */

#include <stdint.h>
#include <stdbool.h>

#define TPU_ROWS            4
#define TPU_COLS            4
#define TPU_NUM_WEIGHT_WORDS 5
#define TPU_LUT_SIZE        256

#define TPU_FRAC_BITS       10

/* --------------------------------------------------------------------------
 * TPU MMIO map
 * -------------------------------------------------------------------------- */

#define TPU_CONTROL         0x00
#define TPU_STATUS          0x04

#define TPU_W0_LO           0x10
#define TPU_W0_HI           0x14

#define TPU_W1_LO           0x18
#define TPU_W1_HI           0x1C

#define TPU_W2_LO           0x20
#define TPU_W2_HI           0x24

#define TPU_W3_LO           0x28
#define TPU_W3_HI           0x2C

#define TPU_W4_LO           0x30
#define TPU_W4_HI           0x34

#define TPU_INPUT0_LO       0x38
#define TPU_INPUT0_HI       0x3C

#define TPU_INPUT1_LO       0x40
#define TPU_INPUT1_HI       0x44

#define TPU_RESULT0_LO      0x50
#define TPU_RESULT0_HI      0x54

#define TPU_RESULT1_LO      0x58
#define TPU_RESULT1_HI      0x5C

#define TPU_START_BIT       0
#define TPU_BUSY_BIT        0
#define TPU_DONE_BIT        1

/* --------------------------------------------------------------------------
 * Sigmoid Q5.10 limits
 *
 * -8.0    = -8192
 * +7.9375 =  8128
 * -------------------------------------------------------------------------- */

#define SIGMOID_MIN_Q510    (-8192)
#define SIGMOID_MAX_Q510    ( 8128)

/* --------------------------------------------------------------------------
 * Reference-model state
 * -------------------------------------------------------------------------- */

typedef struct
{
    /* Raw software-visible weight words W0-W4. */
    uint64_t weight_word[TPU_NUM_WEIGHT_WORDS];

    /* Raw software-visible input words. */
    uint64_t input_word[2];

    /*
     * Four activation lanes.
     *
     * Lane order:
     *   [15:0]   -> lane 0
     *   [31:16]  -> lane 1
     *   [47:32]  -> lane 2
     *   [63:48]  -> lane 3
     */
    int16_t a[TPU_ROWS];

    /*
     * Stationary 4x4 B matrix.
     *
     * b[row][column]
     */
    int16_t b[TPU_ROWS][TPU_COLS];

    /* Four final MAC outputs before sigmoid. */
    int16_t mac_result[TPU_COLS];

    /* Four final sigmoid outputs. */
    uint16_t sigmoid_result[TPU_COLS];

    /* Software-visible result registers. */
    uint64_t result0;
    uint64_t result1;

} tpu_ref_model_t;


/* --------------------------------------------------------------------------
 * Initialization
 * -------------------------------------------------------------------------- */

void tpu_ref_model_init(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * Utility functions
 * -------------------------------------------------------------------------- */

uint64_t tpu_make_u64(uint32_t lo, uint32_t hi);

void tpu_unpack_4x16(uint64_t word, int16_t lane[4]);


/* --------------------------------------------------------------------------
 * Input extraction
 * -------------------------------------------------------------------------- */

void tpu_extract_inputs(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * Weight mapping
 *
 * The implementation must follow the verified nn.v controller schedule.
 * -------------------------------------------------------------------------- */

void tpu_map_weights_to_pe(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * PE arithmetic
 * -------------------------------------------------------------------------- */

/*
 * One PE operation:
 *
 *   product = signed16(a) * signed16(b)
 *
 *   contribution = signed_truncate16(product >> 10)
 *
 *   output = 16-bit modulo(output + contribution)
 */
int16_t tpu_pe_operation(int16_t y_in,
                         int16_t a_in,
                         int16_t b);


/* --------------------------------------------------------------------------
 * 4x4 dataflow computation
 * -------------------------------------------------------------------------- */

void tpu_compute_mac(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * Sigmoid
 * -------------------------------------------------------------------------- */

uint8_t tpu_sigmoid_address(int16_t din); // why 8 

uint16_t tpu_sigmoid(int16_t din); 

void tpu_compute_sigmoid(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * Result packing
 * -------------------------------------------------------------------------- */

void tpu_pack_results(tpu_ref_model_t *model);


/* --------------------------------------------------------------------------
 * Complete reference calculation
 * -------------------------------------------------------------------------- */

void tpu_run(tpu_ref_model_t *model);

#endif
