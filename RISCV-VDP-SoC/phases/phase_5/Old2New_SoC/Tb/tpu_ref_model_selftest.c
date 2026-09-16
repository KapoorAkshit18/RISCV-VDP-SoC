#include "tpu_ref_model.h"
#include <inttypes.h>
#include <stdio.h>

static uint64_t pack4(int16_t x0, int16_t x1, int16_t x2, int16_t x3)
{
    return ((uint64_t)(uint16_t)x0 << 0)  |
           ((uint64_t)(uint16_t)x1 << 16) |
           ((uint64_t)(uint16_t)x2 << 32) |
           ((uint64_t)(uint16_t)x3 << 48);
}

int main(void)
{
    uint64_t axi[7] = {
        pack4(1, 2, 3, 4),       /* weight0 -> wb[0] */
        pack4(5, 6, 7, 8),       /* weight1 -> wb[1] */
        pack4(9, 10, 11, 12),    /* weight2 -> wb[2] */
        pack4(13, 14, 15, 16),   /* weight3 -> wb[3] */
        pack4(17, 18, 19, 20),   /* weight4 -> wb[4] */
        pack4(1, 2, 3, 4),       /* input0 -> k[0] */
        pack4(5, 6, 7, 8)        /* input1 -> k[1] */
    };

    uint64_t result0, result1;

    tpu_reference(axi, &result0, &result1);

    printf("RESULT0 = 0x%016" PRIx64 "\n", result0);
    printf("RESULT1 = 0x%016" PRIx64 "\n", result1);

    return 0;
}
