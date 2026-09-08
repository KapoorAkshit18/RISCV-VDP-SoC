#include <stdint.h>

#define INPUT_SIZE  32  // provides a fixed-size input vector for the workload
#define OUTPUT_SIZE 32  // provides a fixed-size output vector for the workload

/* ---------------------------------------------------------
 * Debug / benchmark variables
 * Keep these global and volatile so they are easy to observe
 * in the RAM waveform.
 * --------------------------------------------------------- */
volatile uint32_t debug_marker;
volatile uint32_t benchmark_cycles_lo;
volatile uint32_t benchmark_cycles_hi;

volatile int32_t output[OUTPUT_SIZE];

/* ---------------------------------------------------------
 * Input vector
 * 1,2,...,16,16,...,2,1
 * --------------------------------------------------------- */
static const int32_t input[INPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    16, 15, 14, 13, 12, 11, 10,  9,
     8,  7,  6,  5,  4,  3,  2,  1
};

/* ---------------------------------------------------------
 * Weight matrix
 * Row i contains (i+1)
 *
 * W[0] = 1,1,...,1
 * W[1] = 2,2,...,2
 * ...
 * W[31] = 32,32,...,32
 * --------------------------------------------------------- */
static const int32_t weights[OUTPUT_SIZE][INPUT_SIZE] = {
    { [0 ... 31] = 1  },
    { [0 ... 31] = 2  },
    { [0 ... 31] = 3  },
    { [0 ... 31] = 4  },
    { [0 ... 31] = 5  },
    { [0 ... 31] = 6  },
    { [0 ... 31] = 7  },
    { [0 ... 31] = 8  },
    { [0 ... 31] = 9  },
    { [0 ... 31] = 10 },
    { [0 ... 31] = 11 },
    { [0 ... 31] = 12 },
    { [0 ... 31] = 13 },
    { [0 ... 31] = 14 },
    { [0 ... 31] = 15 },
    { [0 ... 31] = 16 },
    { [0 ... 31] = 17 },
    { [0 ... 31] = 18 },
    { [0 ... 31] = 19 },
    { [0 ... 31] = 20 },
    { [0 ... 31] = 21 },
    { [0 ... 31] = 22 },
    { [0 ... 31] = 23 },
    { [0 ... 31] = 24 },
    { [0 ... 31] = 25 },
    { [0 ... 31] = 26 },
    { [0 ... 31] = 27 },
    { [0 ... 31] = 28 },
    { [0 ... 31] = 29 },
    { [0 ... 31] = 30 },
    { [0 ... 31] = 31 },
    { [0 ... 31] = 32 }
};

/* ---------------------------------------------------------
 * Bias
 * --------------------------------------------------------- */
static const int32_t bias[OUTPUT_SIZE] = {
     1,  2,  3,  4,  5,  6,  7,  8,
     9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 31, 32
};

/* ---------------------------------------------------------
 * Read 32-bit cycle counter safely
 * --------------------------------------------------------- */
static inline uint32_t rdcycle_lo(void)
{
    uint32_t lo;

    asm volatile (
        "rdcycle %0"
        : "=r"(lo)
    );                                   

    return lo;
}

static inline uint32_t rdcycle_hi(void)
{
    uint32_t hi;

    asm volatile (
        "rdcycleh %0"
        : "=r"(hi)
    );

    return hi;
}

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

/* ---------------------------------------------------------
 * Software Matrix-Vector Multiplication + ReLU
 *
 * y[i] = ReLU(
 *          bias[i] +
 *          SUM(input[j] * weights[i][j])
 *        )
 *
 * Total MACs = 32 x 32 = 1024
 * --------------------------------------------------------- */
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

        /* ReLU */
        if (accumulator < 0)
        {
            accumulator = 0;
        }

        output[i] = accumulator;
    }
}

/* ---------------------------------------------------------
 * Main benchmark
 * --------------------------------------------------------- */
int main(void)
{
    uint64_t start_cycles;
    uint64_t end_cycles;
    uint64_t workload_cycles;

    /*
     * 0x11111111 = workload about to start
     */
    debug_marker = 0x11111111;

    start_cycles = read_cycle64();

    /* -----------------------------------------------
     * SOFTWARE BASELINE
     * ----------------------------------------------- */
    run_workload();

    end_cycles = read_cycle64();

    /*
     * 0x22222222 = workload completed
     */
    debug_marker = 0x22222222;

    workload_cycles = end_cycles - start_cycles;

    /* -----------------------------------------------
     * Verify results
     *
     * sum(input) = 272
     *
     * output[i] =
     *     (i+1) * 272 + (i+1)
     *   = (i+1) * 273
     * ----------------------------------------------- */
    for (int i = 0; i < OUTPUT_SIZE; i++)
    {
        int32_t expected = (i + 1) * 273;

        if (output[i] != expected)
        {
            /*
             * Verification failure
             */
            debug_marker = 0xDEAD0001;

            while (1)
            {
                ;
            }
        }
    }

    /* -----------------------------------------------
     * Store benchmark result in RAM
     * ----------------------------------------------- */
    benchmark_cycles_lo =
        (uint32_t)(workload_cycles & 0xFFFFFFFFULL);

    benchmark_cycles_hi =
        (uint32_t)(workload_cycles >> 32);

    /*
     * 0x33333333 = benchmark completely finished
     */
    debug_marker = 0x33333333;

    /* Stop CPU */
    while (1)
    {
        ;
    }

    return 0;
}