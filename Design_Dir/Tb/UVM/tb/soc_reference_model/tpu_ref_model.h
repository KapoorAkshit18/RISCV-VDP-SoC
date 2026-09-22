#ifndef TPU_REF_MODEL_H
#define TPU_REF_MODEL_H

#include <stdint.h>
#include <stddef.h>
#include "sigmoid_lut_exact.h"

#ifdef __cplusplus
extern "C" {
#endif

#define TPU_LANES       4
#define TPU_WB_WORDS    5
#define TPU_K_WORDS     2
#define TPU_Q_FRAC      10
#define TPU_ONE_Q      ((int16_t)0x0400)

/*
 * Seven AXI-stream input beats:
 *
 *   beat 0..4 : wb[0..4]  - moving systolic input words
 *   beat 5..6 : k[0..1]   - source words used to initialise stationary b
 *
 * Each 64-bit word is unpacked little-lane first:
 *   lane 0 = bits 15:0
 *   lane 1 = bits 31:16
 *   lane 2 = bits 47:32
 *   lane 3 = bits 63:48
 */
typedef struct {
    uint64_t wb[TPU_WB_WORDS];
    uint64_t k[TPU_K_WORDS];
} tpu_input_t;

typedef struct {
    /* Four stationary rows, four signed Q6.10 values per row. */
    int16_t b[TPU_LANES][TPU_LANES];

    /* Four moving values for the currently consumed wb word. */
    int16_t a[TPU_LANES];

    /* Four sigmoid outputs and the two packed output beats. */
    uint16_t sigmoid[TPU_LANES];
    uint64_t result0;
    uint64_t result1;
} tpu_state_t;

/* Initialise the input packet to zero. */
void tpu_input_clear(tpu_input_t *in);

/* Execute the specified TPU computation. */
void tpu_run(const tpu_input_t *in, tpu_state_t *state);

/* Convenience wrapper returning the two software-visible AXI beats. */
void tpu_reference(const uint64_t axi_words[7],
                   uint64_t *result0,
                   uint64_t *result1);

/* Exact RTL-compatible signed PE operation. */
int16_t tpu_pe_mac(int16_t a, int16_t b, int16_t y);

/* Exact sigmoid lookup operation. */
uint16_t tpu_sigmoid(uint16_t din);

#ifdef __cplusplus
}
#endif

#endif
