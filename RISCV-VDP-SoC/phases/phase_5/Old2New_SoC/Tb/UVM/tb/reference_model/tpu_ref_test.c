/*
 * ============================================================================
 * TPU C GOLDEN MODEL SELF-TEST
 * ============================================================================
 *
 * Verifies the fixed-point and sigmoid-addressing semantics independently
 * of the UVM environment.
 * ============================================================================
 */

#include <stdio.h>
#include <stdint.h>

#include "tpu_ref_model.h"


/* ============================================================================
 * Address test helper
 * ========================================================================== */

static int check_address(int16_t din,
                         uint8_t expected,
                         const char *name)
{
    uint8_t actual = tpu_sigmoid_address(din);

    if (actual != expected)
    {
        printf(
            "FAIL: %-24s din=%d expected=0x%02X actual=0x%02X\n",
            name,
            din,
            expected,
            actual
        );

        return 0;
    }

    printf(
        "PASS: %-24s din=%d address=0x%02X\n",
        name,
        din,
        actual
    );

    return 1;
}


/* ============================================================================
 * Sigmoid Q5.10 saturation test
 * ========================================================================== */

static int test_sigmoid_saturation(void)
{
    int pass = 1;

    printf("\n");
    printf("============================================================\n");
    printf("SIGMOID Q5.10 SATURATION TEST\n");
    printf("============================================================\n");

    /*
     * Q5.10:
     *
     *     -8.0    = -8192
     *     -7.9375 = -8128
     *     +7.9375 = 8128
     */

    pass &= check_address(
        -8193,
        0x80,
        "below -8.0"
    );

    pass &= check_address(
        -8192,
        0x80,
        "exactly -8.0"
    );

    pass &= check_address(
        -8128,
        0x81,
        "exactly -7.9375"
    );

    pass &= check_address(
        0,
        0x00,
        "zero"
    );

    pass &= check_address(
        8128,
        0x7F,
        "exactly +7.9375"
    );

    pass &= check_address(
        8129,
        0x7F,
        "above +7.9375"
    );

    return pass;
}


/* ============================================================================
 * Lane unpacking test
 * ========================================================================== */

static int test_lane_unpack(void)
{
    int16_t lane[4];

    uint64_t word =
        ((uint64_t)(uint16_t)-4 << 48) |
        ((uint64_t)(uint16_t) 3 << 32) |
        ((uint64_t)(uint16_t)-2 << 16) |
        ((uint64_t)(uint16_t) 1);

    tpu_unpack_4x16(word, lane);

    if (lane[0] != 1 ||
        lane[1] != -2 ||
        lane[2] != 3 ||
        lane[3] != -4)
    {
        printf("FAIL: 64-bit signed lane unpacking\n");
        return 0;
    }

    printf("PASS: 64-bit signed lane unpacking\n");

    return 1;
}


/* ============================================================================
 * PE arithmetic test
 * ========================================================================== */

static int test_pe_operation(void)
{
    int16_t result;

    /*
     * Example:
     *
     *     a = 1024  -> +1.0
     *     b = 2048  -> +2.0
     *
     * Product:
     *
     *     1024 * 2048 = 2097152
     *
     * >>10:
     *
     *     2048
     *
     * Therefore:
     *
     *     y_out = 2048
     */
    result = tpu_pe_operation(
        0,
        1024,
        2048
    );

    if (result != 2048)
    {
        printf(
            "FAIL: PE arithmetic expected=2048 actual=%d\n",
            result
        );

        return 0;
    }

    printf("PASS: PE fixed-point arithmetic\n");

    return 1;
}


/* ============================================================================
 * 16-bit wrap-around test
 * ========================================================================== */

static int test_wraparound(void)
{
    int16_t result;

    /*
     * 32767 + 1 = 0x8000 in modulo-2^16 arithmetic.
     *
     * The resulting signed value is -32768.
     */
    result = tpu_pe_operation(
        32767,
        1024,
        1
    );

    if (result != (int16_t)0x8000)
    {
        printf(
            "FAIL: 16-bit wrap-around expected=-32768 actual=%d\n",
            result
        );

        return 0;
    }

    printf("PASS: 16-bit modulo wrap-around\n");

    return 1;
}


/* ============================================================================
 * Main
 * ========================================================================== */

int main(void)
{
    int pass = 1;

    printf("\n");
    printf("============================================================\n");
    printf("TPU C GOLDEN REFERENCE MODEL\n");
    printf("============================================================\n");

    pass &= test_sigmoid_saturation();
    pass &= test_lane_unpack();
    pass &= test_pe_operation();
    pass &= test_wraparound();

    printf("\n");

    if (pass)
    {
        printf("============================================================\n");
        printf("ALL REFERENCE MODEL TESTS PASSED\n");
        printf("============================================================\n");

        return 0;
    }

    printf("============================================================\n");
    printf("REFERENCE MODEL TEST FAILED\n");
    printf("============================================================\n");

    return 1;
}