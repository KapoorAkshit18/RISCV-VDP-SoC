#include <stdint.h>

/*
 * ============================================================
 * RISC-V SoC - Software Workload Benchmark
 * ============================================================
 *
 * Workload:
 *     Matrix-Vector Multiplication followed by ReLU
 *
 *     y[i] = ReLU( sum(x[j] * W[i][j]) + bias[i] )
 *
 * Configuration:
 *     INPUT_SIZE  = 32
 *     OUTPUT_SIZE = 32
 *
 * Total MAC operations:
 *     32 x 32 = 1024 multiply-accumulate operations
 *
 * This workload is intentionally implemented as ordinary
 * software to establish the pre-TPU software baseline.
 *
 * The same input data, weights, dimensions and mathematical
 * operation should be used for the TPU measurement.
 * ============================================================
 */

#define INPUT_SIZE  32
#define OUTPUT_SIZE 32

/* Input vector */
static const int32_t input[INPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    16, 15, 14, 13, 12, 11, 10,  9,
     8,  7,  6,  5,  4,  3,  2,  1
};

/*
 * Weight matrix.
 *
 * Each row contains a constant value. This deterministic
 * pattern makes the expected result easy to verify.
 */
static const int32_t weights[OUTPUT_SIZE][INPUT_SIZE] = {
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},

    {2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2},

    {3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
     3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3},

    {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
     4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4},

    {5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
     5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5},

    {6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
     6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6},

    {7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
     7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7},

    {8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
     8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8},

    {9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
     9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9},

    {10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
     10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10},

    {11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,
     11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11},

    {12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
     12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12},

    {13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,
     13,13,13,13,13,13,13,13,13,13,13,13,13,13,13,13},

    {14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,
     14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14},

    {15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
     15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15},

    {16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
     16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16},

    {17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,
     17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17},

    {18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,
     18,18,18,18,18,18,18,18,18,18,18,18,18,18,18,18},

    {19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,
     19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19},

    {20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,
     20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20},

    {21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,
     21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21},

    {22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,
     22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22},

    {23,23,23,23,23,23,23,23,23,23,23,23,23,23,23,23,
     23,23,23,23,23,23,23,23,23,23,23,23,23,23,23,23},

    {24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,
     24,24,24,24,24,24,24,24,24,24,24,24,24,24,24,24},

    {25,25,25,25,25,25,25,25,25,25,25,25,25,25,25,25,
     25,25,25,25,25,25,25,25,25,25,25,25,25,25,25,25},

    {26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
     26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26},

    {27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,
     27,27,27,27,27,27,27,27,27,27,27,27,27,27,27,27},

    {28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,
     28,28,28,28,28,28,28,28,28,28,28,28,28,28,28,28},

    {29,29,29,29,29,29,29,29,29,29,29,29,29,29,29,29,
     29,29,29,29,29,29,29,29,29,29,29,29,29,29,29,29},

    {30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,
     30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30},

    {31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,
     31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31},

    {32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,
     32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32}
};

/* Bias values */
static const int32_t bias[OUTPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32
};

/* Output vector */
static int32_t output[OUTPUT_SIZE];

/*
 * ============================================================
 * RISC-V Cycle Counter
 * ============================================================
 */

/* Read lower 32 bits of cycle counter */
static inline uint32_t rdcycle_lo(void)
{
    uint32_t lo;

    asm volatile ("rdcycle %0" : "=r"(lo));

    return lo;
}

/* Read upper 32 bits of cycle counter */
static inline uint32_t rdcycle_hi(void)
{
    uint32_t hi;

    asm volatile ("rdcycleh %0" : "=r"(hi));

    return hi;
}

/*
 * Safely read the 64-bit cycle counter on RV32.
 *
 * The high word is read before and after the low word.
 * If the high word changes, the read is repeated.
 */
static inline uint64_t read_cycle64(void)
{
    uint32_t hi1;
    uint32_t lo;
    uint32_t hi2;

    do {
        hi1 = rdcycle_hi();
        lo  = rdcycle_lo();
        hi2 = rdcycle_hi();
    } while (hi1 != hi2);

    return ((uint64_t)hi1 << 32) | lo;
}

/*
 * ============================================================
 * Matrix-Vector Multiplication + ReLU
 * ============================================================
 *
 * y[i] = ReLU( sum(x[j] * W[i][j]) + bias[i] )
 *
 * Total:
 *     32 x 32 = 1024 multiply-accumulate operations
 */
static void run_workload(void)
{
    int i;
    int j;

    for (i = 0; i < OUTPUT_SIZE; i++)
    {
        int32_t accumulator = bias[i];

        for (j = 0; j < INPUT_SIZE; j++)
        {
            accumulator += input[j] * weights[i][j];
        }

        /* ReLU: max(0, accumulator) */
        if (accumulator < 0)
        {
            accumulator = 0;
        }

        output[i] = accumulator;
    }
}

/*
 * ============================================================
 * Main Benchmark
 * ============================================================
 */
int main(void)
{
    uint64_t start_cycles;
    uint64_t end_cycles;
    uint64_t workload_cycles;

    /*
     * --------------------------------------------------------
     * WORKLOAD START
     * --------------------------------------------------------
     *
     * Only the actual software computation is measured.
     */
    start_cycles = read_cycle64();

    run_workload();

    end_cycles = read_cycle64();

    workload_cycles = end_cycles - start_cycles;

    /*
     * --------------------------------------------------------
     * WORKLOAD END
     * --------------------------------------------------------
     *
     * Verify the computation.
     *
     * sum(input) = 528
     *
     * Therefore:
     * output[i] = (i + 1) * 528 + (i + 1)
     *            = (i + 1) * 529
     */
    for (int i = 0; i < OUTPUT_SIZE; i++)
    {
        int32_t expected = (i + 1) * 529;

        if (output[i] != expected)
        {
            /* Computation failed */
            while (1)
            {
                ;
            }
        }
    }

    /*
     * Store the measured workload latency in memory.
     *
     * These variables can be observed from the simulation
     * waveform or through the generated memory image.
     */
    volatile uint32_t benchmark_cycles_lo;
    volatile uint32_t benchmark_cycles_hi;

    benchmark_cycles_lo =
        (uint32_t)(workload_cycles & 0xFFFFFFFFULL);

    benchmark_cycles_hi =
        (uint32_t)(workload_cycles >> 32);

    /*
     * Workload completed successfully.
     *
     * CPU remains here so the end of execution is clearly
     * visible in the simulation waveform.
     */
    while (1)
    {
        ;
    }

    return 0;
}