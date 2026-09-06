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
 * software so that the execution time can be used as the
 * pre-TPU baseline.
 *
 * Phase 1:
 *     RISC-V CPU executes the complete workload.
 *
 * Phase 5:
 *     The equivalent workload will be executed using the TPU.
 *
 * The same input data, weights, dimensions and mathematical
 * operation should be used for both measurements.
 * ============================================================
 */

#define INPUT_SIZE   32
#define OUTPUT_SIZE  32

/*
 * Input vector.
 */
static const int32_t input[INPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    16, 15, 14, 13, 12, 11, 10,  9,
     8,  7,  6,  5,  4,  3,  2,  1
};

/*
 * Weight matrix.
 *
 * A deterministic pattern is used instead of random values so
 * that the result can be reproduced exactly in simulation and
 * compared against the TPU result.
 */
static const int32_t weights[OUTPUT_SIZE][INPUT_SIZE] = {
    { 1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1,
      1, 1, 1, 1, 1, 1, 1, 1 },

    { 2, 2, 2, 2, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2,
      2, 2, 2, 2, 2, 2, 2, 2 },

    { 3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3,
      3, 3, 3, 3, 3, 3, 3, 3 },

    { 4, 4, 4, 4, 4, 4, 4, 4,
      4, 4, 4, 4, 4, 4, 4, 4,
      4, 4, 4, 4, 4, 4, 4, 4,
      4, 4, 4, 4, 4, 4, 4, 4 },

    { 5, 5, 5, 5, 5, 5, 5, 5,
      5, 5, 5, 5, 5, 5, 5, 5,
      5, 5, 5, 5, 5, 5, 5, 5,
      5, 5, 5, 5, 5, 5, 5, 5 },

    { 6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6,
      6, 6, 6, 6, 6, 6, 6, 6 },

    { 7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7,
      7, 7, 7, 7, 7, 7, 7, 7 },

    { 8, 8, 8, 8, 8, 8, 8, 8,
      8, 8, 8, 8, 8, 8, 8, 8,
      8, 8, 8, 8, 8, 8, 8, 8,
      8, 8, 8, 8, 8, 8, 8, 8 },

    { 9, 9, 9, 9, 9, 9, 9, 9,
      9, 9, 9, 9, 9, 9, 9, 9,
      9, 9, 9, 9, 9, 9, 9, 9,
      9, 9, 9, 9, 9, 9, 9, 9 },

    {10,10,10,10,10,10,10,10,
     10,10,10,10,10,10,10,10,
     10,10,10,10,10,10,10,10,
     10,10,10,10,10,10,10,10 },

    {11,11,11,11,11,11,11,11,
     11,11,11,11,11,11,11,11,
     11,11,11,11,11,11,11,11,
     11,11,11,11,11,11,11,11 },

    {12,12,12,12,12,12,12,12,
     12,12,12,12,12,12,12,12,
     12,12,12,12,12,12,12,12,
     12,12,12,12,12,12,12,12 },

    {13,13,13,13,13,13,13,13,
     13,13,13,13,13,13,13,13,
     13,13,13,13,13,13,13,13,
     13,13,13,13,13,13,13,13 },

    {14,14,14,14,14,14,14,14,
     14,14,14,14,14,14,14,14,
     14,14,14,14,14,14,14,14,
     14,14,14,14,14,14,14,14 },

    {15,15,15,15,15,15,15,15,
     15,15,15,15,15,15,15,15,
     15,15,15,15,15,15,15,15,
     15,15,15,15,15,15,15,15 },

    {16,16,16,16,16,16,16,16,
     16,16,16,16,16,16,16,16,
     16,16,16,16,16,16,16,16,
     16,16,16,16,16,16,16,16 },

    {17,17,17,17,17,17,17,17,
     17,17,17,17,17,17,17,17,
     17,17,17,17,17,17,17,17,
     17,17,17,17,17,17,17,17 },

    {18,18,18,18,18,18,18,18,
     18,18,18,18,18,18,18,18,
     18,18,18,18,18,18,18,18,
     18,18,18,18,18,18,18,18 },

    {19,19,19,19,19,19,19,19,
     19,19,19,19,19,19,19,19,
     19,19,19,19,19,19,19,19,
     19,19,19,19,19,19,19,19 },

    {20,20,20,20,20,20,20,20,
     20,20,20,20,20,20,20,20,
     20,20,20,20,20,20,20,20,
     20,20,20,20,20,20,20,20 },

    {21,21,21,21,21,21,21,21,
     21,21,21,21,21,21,21,21,
     21,21,21,21,21,21,21,21,
     21,21,21,21,21,21,21,21 },

    {22,22,22,22,22,22,22,22,
     22,22,22,22,22,22,22,22,
     22,22,22,22,22,22,22,22,
     22,22,22,22,22,22,22,22 },

    {23,23,23,23,23,23,23,23,
     23,23,23,23,23,23,23,23,
     23,23,23,23,23,23,23,23,
     23,23,23,23,23,23,23,23 },

    {24,24,24,24,24,24,24,24,
     24,24,24,24,24,24,24,24,
     24,24,24,24,24,24,24,24,
     24,24,24,24,24,24,24,24 },

    {25,25,25,25,25,25,25,25,
     25,25,25,25,25,25,25,25,
     25,25,25,25,25,25,25,25,
     25,25,25,25,25,25,25,25 },

    {26,26,26,26,26,26,26,26,
     26,26,26,26,26,26,26,26,
     26,26,26,26,26,26,26,26,
     26,26,26,26,26,26,26,26 },

    {27,27,27,27,27,27,27,27,
     27,27,27,27,27,27,27,27,
     27,27,27,27,27,27,27,27,
     27,27,27,27,27,27,27,27 },

    {28,28,28,28,28,28,28,28,
     28,28,28,28,28,28,28,28,
     28,28,28,28,28,28,28,28,
     28,28,28,28,28,28,28,28 },

    {29,29,29,29,29,29,29,29,
     29,29,29,29,29,29,29,29,
     29,29,29,29,29,29,29,29,
     29,29,29,29,29,29,29,29 },

    {30,30,30,30,30,30,30,30,
     30,30,30,30,30,30,30,30,
     30,30,30,30,30,30,30,30,
     30,30,30,30,30,30,30,30 },

    {31,31,31,31,31,31,31,31,
     31,31,31,31,31,31,31,31,
     31,31,31,31,31,31,31,31,
     31,31,31,31,31,31,31,31 },

    {32,32,32,32,32,32,32,32,
     32,32,32,32,32,32,32,32,
     32,32,32,32,32,32,32,32,
     32,32,32,32,32,32,32,32 }
};

/*
 * Bias values.
 */
static const int32_t bias[OUTPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32
};

/*
 * Output vector.
 */
static int32_t output[OUTPUT_SIZE];

/*
 * ------------------------------------------------------------
 * Matrix-Vector Multiply + ReLU
 * ------------------------------------------------------------
 *
 * This is the computation that forms the software baseline.
 *
 * Each output element requires:
 *
 *     32 multiplications
 *     31 additions
 *     1 bias addition
 *     1 ReLU operation
 *
 * Total:
 *
 *     32 x 32 = 1024 MAC operations
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

        /*
         * ReLU activation:
         *
         * ReLU(x) = max(0, x)
         */
        if (accumulator < 0)
            accumulator = 0;

        output[i] = accumulator;
    }
}

int main(void)
{
    /*
     * --------------------------------------------------------
     * WORKLOAD START
     * --------------------------------------------------------
     *
     * From this point onward, the CPU performs the actual
     * compute workload.
     *
     * This region is the portion to be measured for the
     * software-only baseline.
     */
    run_workload();

    /*
     * --------------------------------------------------------
     * WORKLOAD END
     * --------------------------------------------------------
     *
     * Verify the generated result so that the compiler cannot
     * remove the computation as unused code.
     *
     * The expected result for output[i] is:
     *
     *     output[i] =
     *         i+1 times sum(input) + (i+1)
     *
     * Since sum(input) = 528:
     *
     *     output[i] = (i+1) * 529
     */
    for (int i = 0; i < OUTPUT_SIZE; i++)
    {
        int32_t expected = (i + 1) * 529;

        if (output[i] != expected)
        {
            /*
             * Error condition.
             *
             * Remain here if the computation produced an
             * unexpected result.
             */
            while (1)
                ;
        }
    }


      static inline uint32_t rdcycle_lo(void) {
          uint32_t lo;
          asm volatile ("rdcycle %0" : "=r"(lo));
          return lo;
      }

        static inline uint32_t rdcycle_hi(void) {
            uint32_t hi;
            asm volatile ("rdcycleh %0" : "=r"(hi));
            return hi;
        }

  /* Read 64-bit cycle counter safely (retries if high changes) */
  static uint64_t read_cycle64(void) {
      uint32_t hi1, lo, hi2;
      do {
          hi1 = rdcycle_hi();
          lo  = rdcycle_lo();
          hi2 = rdcycle_hi();
      } while (hi1 != hi2);
      return ((uint64_t)hi1 << 32) | lo;
  }

    /* ... in main, after workload and verification ... */
    volatile uint64_t sim_cycles = 0;
    sim_cycles = read_cycle64();

    /* Make result visible — store into output[] so the testbench/simulator can inspect it */
    output[0] = (uint32_t)(sim_cycles & 0xffffffffUL);       // low 32 bits
    output[1] = (uint32_t)(sim_cycles >> 32);                // high 32 bits

    /*
     * Workload completed successfully.
     *
     * The CPU remains here so that the end of the workload can
     * be identified clearly in the simulation waveform.
     */
    while (1)
        ;

    return 0;
}
