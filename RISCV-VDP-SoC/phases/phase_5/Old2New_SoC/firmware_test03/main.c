/*
 * ============================================================================
 * RISCV-VDP-SoC - Phase 5 Firmware
 * ============================================================================
 *
 * Purpose:
 *   CPU-driven TPU/NN accelerator benchmark.
 *
 * Phase comparison:
 *
 *   Phase 3:
 *     CPU-only software implementation of the fixed-point sigmoid workload.
 *
 *   Phase 5:
 *     CPU configures the integrated TPU through its MMIO register interface,
 *     starts the TPU, waits until completion, reads the two 64-bit result
 *     words, and stores the results in RAM for the SystemVerilog testbench.
 *
 * TPU system base address:
 *   0x00014000
 *
 * Important design assumptions:
 *
 *   1. The CPU is RV32I.
 *   2. CPU data accesses are 32-bit.
 *   3. Every 64-bit TPU register is accessed as two 32-bit words.
 *   4. The low 32-bit word is written/read before the high 32-bit word.
 *   5. CONTROL.START is a write command and uses bit 0.
 *   6. STATUS.BUSY is bit 0.
 *   7. STATUS.DONE is bit 1.
 *   8. DONE remains asserted long enough for software polling to observe it.
 *   9. The TPU wrapper accepts START only when the TPU is idle.
 *  10. The TPU result registers are already available when DONE is asserted.
 *
 * AXI-Stream payload order:
 *
 *   Beat 0 = WEIGHT0
 *   Beat 1 = WEIGHT1
 *   Beat 2 = WEIGHT2
 *   Beat 3 = WEIGHT3
 *   Beat 4 = WEIGHT4
 *   Beat 5 = INPUT0
 *   Beat 6 = INPUT1 with TLAST
 *
 * The seven 64-bit payloads are intentionally identical to the standalone
 * axis_nn_tb stimulus used for TPU verification.
 *
 * Benchmark timing:
 *
 *   The cycle counter starts immediately before TPU MMIO configuration.
 *   The cycle counter stops after both 64-bit result words are read.
 *
 * Therefore, Phase 5 timing includes:
 *
 *   - Seven 64-bit payload configurations
 *   - Fourteen 32-bit MMIO writes
 *   - START command
 *   - TPU execution
 *   - CPU status polling
 *   - Four 32-bit result reads
 *
 * Debug RAM locations:
 *
 *   0x12A0 = elapsed cycle count, low 32 bits
 *   0x12A4 = elapsed cycle count, high 32 bits
 *   0x12A8 = execution status marker
 *
 * Status markers:
 *
 *   0x11111111 = benchmark started
 *   0x22222222 = TPU DONE observed
 *   0x33333333 = results read and stored successfully
 *   0xDEAD0001 = timeout/error
 *
 * Result/debug RAM locations:
 *
 *   0x1230 = RESULT0 low 32 bits
 *   0x1234 = RESULT0 high 32 bits
 *   0x1238 = RESULT1 low 32 bits
 *   0x123C = RESULT1 high 32 bits
 *
 * ============================================================================
 */

#include <stdint.h>

/* ============================================================================
 * TPU BASE ADDRESS
 * ========================================================================== */

#define P5_TPU_BASE                 0x00014000u

/* ============================================================================
 * TPU REGISTER OFFSETS
 * ========================================================================== */

/* Control and status registers */
#define P5_REG_CONTROL              0x0000u
#define P5_REG_STATUS               0x0004u

/* WEIGHT0: 64-bit register split into low/high 32-bit words */
#define P5_REG_WEIGHT0_LO           0x0010u
#define P5_REG_WEIGHT0_HI           0x0014u

/* WEIGHT1: 64-bit register split into low/high 32-bit words */
#define P5_REG_WEIGHT1_LO           0x0018u
#define P5_REG_WEIGHT1_HI           0x001Cu

/* WEIGHT2: 64-bit register split into low/high 32-bit words */
#define P5_REG_WEIGHT2_LO           0x0020u
#define P5_REG_WEIGHT2_HI           0x0024u

/* WEIGHT3: 64-bit register split into low/high 32-bit words */
#define P5_REG_WEIGHT3_LO           0x0028u
#define P5_REG_WEIGHT3_HI           0x002Cu

/* WEIGHT4: 64-bit register split into low/high 32-bit words */
#define P5_REG_WEIGHT4_LO           0x0030u
#define P5_REG_WEIGHT4_HI           0x0034u

/* INPUT0: 64-bit register split into low/high 32-bit words */
#define P5_REG_INPUT0_LO            0x0038u
#define P5_REG_INPUT0_HI            0x003Cu

/* INPUT1: 64-bit register split into low/high 32-bit words */
#define P5_REG_INPUT1_LO            0x0040u
#define P5_REG_INPUT1_HI            0x0044u

/* RESULT0: 64-bit register split into low/high 32-bit words */
#define P5_REG_RESULT0_LO           0x0050u
#define P5_REG_RESULT0_HI           0x0054u

/* RESULT1: 64-bit register split into low/high 32-bit words */
#define P5_REG_RESULT1_LO           0x0058u
#define P5_REG_RESULT1_HI           0x005Cu

/* ============================================================================
 * STATUS BIT DEFINITIONS
 * ========================================================================== */

/*
 * STATUS bit 0:
 *
 *   1 = TPU is busy
 *   0 = TPU is idle
 */
#define P5_STATUS_BUSY              (1u << 0)

/*
 * STATUS bit 1:
 *
 *   1 = TPU operation is complete
 *   0 = TPU operation is not complete
 */
#define P5_STATUS_DONE              (1u << 1)

/* ============================================================================
 * CONTROL BIT DEFINITIONS
 * ========================================================================== */

/*
 * CONTROL bit 0:
 *
 *   Writing 1 issues a START command.
 *
 * The TPU wrapper is expected to treat this as a command pulse. The CPU does
 * not need to continuously hold this bit high.
 */
#define P5_CONTROL_START            (1u << 0)

/* ============================================================================
 * DEBUG RAM ADDRESSES
 * ========================================================================== */

/* Benchmark cycle count */
#define P5_DEBUG_CYCLES_LO          0x000012A0u
#define P5_DEBUG_CYCLES_HI          0x000012A4u

/* Execution status marker */
#define P5_DEBUG_MARKER             0x000012A8u

/* TPU result storage */
#define P5_DEBUG_RESULT0_LO         0x00001230u
#define P5_DEBUG_RESULT0_HI         0x00001234u
#define P5_DEBUG_RESULT1_LO         0x00001238u
#define P5_DEBUG_RESULT1_HI         0x0000123Cu

/* ============================================================================
 * DEBUG MARKERS
 * ========================================================================== */

/*
 * Marker written immediately when main() starts.
 */
#define P5_MARK_START               0x11111111u

/*
 * Marker written after STATUS.DONE is observed.
 */
#define P5_MARK_DONE                0x22222222u

/*
 * Marker written after both result words are read and stored in RAM.
 */
#define P5_MARK_SUCCESS             0x33333333u

/*
 * Marker written if the TPU does not report DONE before the timeout expires.
 */
#define P5_MARK_ERROR               0xDEAD0001u

/* ============================================================================
 * TIMEOUT CONFIGURATION
 * ========================================================================== */

/*
 * This is a CPU polling-loop timeout.
 *
 * It is not directly equal to the number of TPU clock cycles.
 *
 * The timeout protects the simulation from hanging forever if:
 *
 *   - The TPU is not started.
 *   - The MMIO address is incorrect.
 *   - STATUS.DONE is never asserted.
 *   - The AXI-Stream transaction is not generated.
 *   - The TPU remains busy forever.
 */
#define P5_TIMEOUT_COUNT            1000000u

/* ============================================================================
 * 32-BIT VOLATILE MEMORY ACCESS HELPERS
 * ========================================================================== */

/*
 * Write one 32-bit value to a TPU MMIO register.
 *
 * uintptr_t is used before converting the integer address into a pointer.
 * This makes the address-to-pointer conversion explicit for bare-metal code.
 *
 * volatile is required because the address represents hardware registers.
 * Without volatile, the compiler could remove or combine MMIO accesses.
 */
static inline void p5_mmio_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)(P5_TPU_BASE + offset) = value;
}

/*
 * Read one 32-bit value from a TPU MMIO register.
 *
 * volatile ensures that every read reaches the hardware register.
 */
static inline uint32_t p5_mmio_read(uint32_t offset)
{
    return *(volatile uint32_t *)(uintptr_t)(P5_TPU_BASE + offset);
}

/*
 * Write one 32-bit value into the SoC RAM address space.
 *
 * These RAM locations are used by the SystemVerilog testbench to observe:
 *
 *   - Benchmark progress
 *   - Elapsed cycle count
 *   - TPU result values
 *   - Timeout/error status
 */
static inline void p5_ram_write(uint32_t address, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)address = value;
}

/* ============================================================================
 * 64-BIT TPU REGISTER WRITE
 * ========================================================================== */

/*
 * Write a 64-bit value to a TPU register using two 32-bit MMIO writes.
 *
 * Write order:
 *
 *   1. Low 32 bits
 *   2. High 32 bits
 *
 * Example:
 *
 *   value = 0x1122334455667788
 *
 * The following writes are generated:
 *
 *   low register  = 0x55667788
 *   high register = 0x11223344
 *
 * The TPU must store the two halves and combine them internally.
 */
static inline void p5_write64(uint32_t lo_offset,
                              uint32_t hi_offset,
                              uint64_t value)
{
    uint32_t value_lo;
    uint32_t value_hi;

    /*
     * Extract bits [31:0].
     */
    value_lo = (uint32_t)(value & 0xFFFFFFFFULL);

    /*
     * Extract bits [63:32].
     */
    value_hi = (uint32_t)(value >> 32);

    /*
     * Write low half first.
     */
    p5_mmio_write(lo_offset, value_lo);

    /*
     * Write high half second.
     */
    p5_mmio_write(hi_offset, value_hi);
}

/* ============================================================================
 * 64-BIT TPU RESULT READ
 * ========================================================================== */

/*
 * Read a 64-bit TPU register using two 32-bit MMIO reads.
 *
 * Read order:
 *
 *   1. Low 32 bits
 *   2. High 32 bits
 *
 * The result is reconstructed as:
 *
 *   result = {high_word, low_word}
 *
 * Example:
 *
 *   low  = 0x55667788
 *   high = 0x11223344
 *
 * Returned value:
 *
 *   0x1122334455667788
 */
static inline uint64_t p5_read64(uint32_t lo_offset,
                                 uint32_t hi_offset)
{
    uint32_t value_lo;
    uint32_t value_hi;

    /*
     * Read the low 32-bit result register.
     */
    value_lo = p5_mmio_read(lo_offset);

    /*
     * Read the high 32-bit result register.
     */
    value_hi = p5_mmio_read(hi_offset);

    /*
     * Convert both 32-bit values to uint64_t before shifting.
     *
     * The cast is important. Shifting a 32-bit value by 32 bits would be
     * incorrect on a 32-bit expression.
     */
    return ((uint64_t)value_hi << 32) | (uint64_t)value_lo;
}

/* ============================================================================
 * 64-BIT RISC-V CYCLE COUNTER READ
 * ========================================================================== */

/*
 * Read the RISC-V machine cycle counter as a consistent 64-bit value.
 *
 * RV32I exposes the cycle counter as two CSRs:
 *
 *   mcycle   = low 32 bits
 *   mcycleh  = high 32 bits
 *
 * A rollover can occur between reading the high and low words.
 *
 * The safe sequence is:
 *
 *   1. Read high word
 *   2. Read low word
 *   3. Read high word again
 *   4. Repeat if the two high-word reads differ
 *
 * This guarantees that the returned low and high words belong to the same
 * counter value.
 */
static inline uint64_t p5_rdcycle64(void)
{
    uint32_t hi_a;
    uint32_t lo;
    uint32_t hi_b;

    do {
        /*
         * Read the high 32 bits of the cycle counter.
         */
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_a));

        /*
         * Read the low 32 bits of the cycle counter.
         */
        __asm__ volatile ("rdcycle %0" : "=r"(lo));

        /*
         * Read the high 32 bits again.
         */
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_b));

        /*
         * If the high word changed, the low word may have wrapped.
         * Repeat the complete read sequence.
         */
    } while (hi_a != hi_b);

    /*
     * Reconstruct the complete 64-bit cycle count.
     */
    return ((uint64_t)hi_b << 32) | (uint64_t)lo;
}

/* ============================================================================
 * EXACT TPU TEST PAYLOADS
 * ========================================================================== */

/*
 * Each 64-bit payload contains four signed 16-bit lanes.
 *
 * Lane packing:
 *
 *   bits [15:0]  = lane 0
 *   bits [31:16] = lane 1
 *   bits [47:32] = lane 2
 *   bits [63:48] = lane 3
 *
 * The values are stored as uint64_t because the TPU interface is bit-exact.
 * No arithmetic is performed on these payload constants by the firmware.
 */

/* Weight payload for AXI-Stream beat 0 */
static const uint64_t P5_WEIGHT0 = 0x0000B07A0505057AULL;

/* Weight payload for AXI-Stream beat 1 */
static const uint64_t P5_WEIGHT1 = 0x0000FC6603E10314ULL;

/* Weight payload for AXI-Stream beat 2 */
static const uint64_t P5_WEIGHT2 = 0x0000FC70028F0433ULL;

/* Weight payload for AXI-Stream beat 3 */
static const uint64_t P5_WEIGHT3 = 0xF5A30051FAC21870ULL;

/* Weight payload for AXI-Stream beat 4 */
static const uint64_t P5_WEIGHT4 = 0x00CC07E10685E399ULL;

/* Input payload for AXI-Stream beat 5 */
static const uint64_t P5_INPUT0  = 0x1400140020002000ULL;

/*
 * Input payload for AXI-Stream beat 6.
 *
 * This is the final payload and is expected to generate TLAST in the TPU
 * wrapper's AXI-Stream transaction.
 */
static const uint64_t P5_INPUT1  = 0x1400200014002000ULL;

/* ============================================================================
 * MAIN BENCHMARK
 * ========================================================================== */

int main(void)
{
    uint64_t start_cycles;
    uint64_t end_cycles;
    uint64_t elapsed_cycles;

    uint64_t result0;
    uint64_t result1;

    uint32_t status;
    uint32_t timeout;

    /*
     * Initialize the software timeout counter.
     */
    timeout = 0u;

    /* ------------------------------------------------------------------------
     * Mark benchmark entry
     * ---------------------------------------------------------------------- */

    /*
     * This marker confirms that the CPU reached the Phase 5 firmware.
     *
     * If the testbench never observes this value, the problem is likely
     * related to:
     *
     *   - Firmware loading
     *   - CPU reset/startup
     *   - Program counter
     *   - RAM initialization
     *   - Debug RAM address mapping
     */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_START);

    /* ------------------------------------------------------------------------
     * Start benchmark timing
     * ---------------------------------------------------------------------- */

    /*
     * Timing starts before any TPU configuration writes.
     *
     * The measured interval includes:
     *
     *   - All weight MMIO writes
     *   - All input MMIO writes
     *   - START command
     *   - TPU execution
     *   - STATUS polling
     *   - Result MMIO reads
     */
    start_cycles = p5_rdcycle64();

    /* ------------------------------------------------------------------------
     * Configure TPU WEIGHT0
     * ---------------------------------------------------------------------- */

    /*
     * Write the exact 64-bit WEIGHT0 payload as two 32-bit transactions.
     */
    p5_write64(P5_REG_WEIGHT0_LO,
               P5_REG_WEIGHT0_HI,
               P5_WEIGHT0);

    /* ------------------------------------------------------------------------
     * Configure TPU WEIGHT1
     * ---------------------------------------------------------------------- */

    p5_write64(P5_REG_WEIGHT1_LO,
               P5_REG_WEIGHT1_HI,
               P5_WEIGHT1);

    /* ------------------------------------------------------------------------
     * Configure TPU WEIGHT2
     * ---------------------------------------------------------------------- */

    p5_write64(P5_REG_WEIGHT2_LO,
               P5_REG_WEIGHT2_HI,
               P5_WEIGHT2);

    /* ------------------------------------------------------------------------
     * Configure TPU WEIGHT3
     * ---------------------------------------------------------------------- */

    p5_write64(P5_REG_WEIGHT3_LO,
               P5_REG_WEIGHT3_HI,
               P5_WEIGHT3);

    /* ------------------------------------------------------------------------
     * Configure TPU WEIGHT4
     * ---------------------------------------------------------------------- */

    p5_write64(P5_REG_WEIGHT4_LO,
               P5_REG_WEIGHT4_HI,
               P5_WEIGHT4);

    /* ------------------------------------------------------------------------
     * Configure TPU INPUT0
     * ---------------------------------------------------------------------- */

    p5_write64(P5_REG_INPUT0_LO,
               P5_REG_INPUT0_HI,
               P5_INPUT0);

    /* ------------------------------------------------------------------------
     * Configure TPU INPUT1
     * ---------------------------------------------------------------------- */

    /*
     * INPUT1 is the final AXI-Stream payload.
     *
     * The TPU wrapper should use this payload as:
     *
     *   beat 6 = INPUT1 + TLAST
     */
    p5_write64(P5_REG_INPUT1_LO,
               P5_REG_INPUT1_HI,
               P5_INPUT1);

    /* ------------------------------------------------------------------------
     * Issue TPU START command
     * ---------------------------------------------------------------------- */

    /*
     * All seven payloads have now been written.
     *
     * The START command is issued only after:
     *
     *   - WEIGHT0 is configured
     *   - WEIGHT1 is configured
     *   - WEIGHT2 is configured
     *   - WEIGHT3 is configured
     *   - WEIGHT4 is configured
     *   - INPUT0 is configured
     *   - INPUT1 is configured
     *
     * The TPU wrapper is expected to accept this command only when it is idle.
     */
    p5_mmio_write(P5_REG_CONTROL, P5_CONTROL_START);

    /* ------------------------------------------------------------------------
     * Poll TPU STATUS until DONE
     * ---------------------------------------------------------------------- */

    while (1) {

        /*
         * Read the TPU status register.
         *
         * Expected status behavior:
         *
         *   BUSY = 1 while the TPU is processing
         *   DONE = 1 when the TPU has completed the operation
         */
        status = p5_mmio_read(P5_REG_STATUS);

        /*
         * Check the DONE bit.
         *
         * DONE must remain asserted long enough for the CPU to observe it.
         */
        if ((status & P5_STATUS_DONE) != 0u) {
            break;
        }

        /*
         * Increment the software polling timeout.
         *
         * This counts CPU polling iterations, not TPU clock cycles.
         */
        timeout++;

        /*
         * Stop waiting if the TPU does not complete within the safety limit.
         */
        if (timeout >= P5_TIMEOUT_COUNT) {

            /* --------------------------------------------------------------
             * Timeout/error path
             * ---------------------------------------------------------- */

            /*
             * Capture the cycle counter even for a failed benchmark.
             *
             * This allows the testbench to diagnose how long the CPU waited
             * before entering the terminal error loop.
             */
            end_cycles = p5_rdcycle64();

            /*
             * Calculate elapsed time.
             */
            elapsed_cycles = end_cycles - start_cycles;

            /*
             * Store elapsed cycle count, low 32 bits.
             */
            p5_ram_write(P5_DEBUG_CYCLES_LO,
                         (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));

            /*
             * Store elapsed cycle count, high 32 bits.
             */
            p5_ram_write(P5_DEBUG_CYCLES_HI,
                         (uint32_t)(elapsed_cycles >> 32));

            /*
             * Store the timeout/error marker.
             */
            p5_ram_write(P5_DEBUG_MARKER, P5_MARK_ERROR);

            /*
             * Terminal error state.
             *
             * The CPU remains here so the simulation does not continue into
             * unrelated memory accesses.
             */
            while (1) {
                __asm__ volatile ("nop");
            }
        }
    }

    /* ------------------------------------------------------------------------
     * TPU DONE observed
     * ---------------------------------------------------------------------- */

    /*
     * Reaching this point means STATUS.DONE was observed by the CPU.
     *
     * This does not yet prove that the numerical result is correct.
     * It only proves that the TPU reported completion.
     */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_DONE);

    /* ------------------------------------------------------------------------
     * Read TPU RESULT0
     * ---------------------------------------------------------------------- */

    /*
     * RESULT0 is a 64-bit register split into:
     *
     *   RESULT0_LO at offset 0x50
     *   RESULT0_HI at offset 0x54
     */
    result0 = p5_read64(P5_REG_RESULT0_LO,
                        P5_REG_RESULT0_HI);

    /* ------------------------------------------------------------------------
     * Read TPU RESULT1
     * ---------------------------------------------------------------------- */

    /*
     * RESULT1 is a 64-bit register split into:
     *
     *   RESULT1_LO at offset 0x58
     *   RESULT1_HI at offset 0x5C
     */
    result1 = p5_read64(P5_REG_RESULT1_LO,
                        P5_REG_RESULT1_HI);

    /* ------------------------------------------------------------------------
     * Stop benchmark timing
     * ---------------------------------------------------------------------- */

    /*
     * Timing stops after both result words have been read.
     *
     * This includes the cost of reading:
     *
     *   - RESULT0 low word
     *   - RESULT0 high word
     *   - RESULT1 low word
     *   - RESULT1 high word
     */
    end_cycles = p5_rdcycle64();

    /*
     * Calculate total Phase 5 elapsed cycles.
     */
    elapsed_cycles = end_cycles - start_cycles;

    /* ------------------------------------------------------------------------
     * Store elapsed cycle count in debug RAM
     * ---------------------------------------------------------------------- */

    /*
     * Store low 32 bits of elapsed cycle count.
     */
    p5_ram_write(P5_DEBUG_CYCLES_LO,
                 (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));

    /*
     * Store high 32 bits of elapsed cycle count.
     */
    p5_ram_write(P5_DEBUG_CYCLES_HI,
                 (uint32_t)(elapsed_cycles >> 32));

    /* ------------------------------------------------------------------------
     * Store RESULT0 in debug RAM
     * ---------------------------------------------------------------------- */

    /*
     * Store RESULT0 low 32 bits at RAM address 0x1230.
     */
    p5_ram_write(P5_DEBUG_RESULT0_LO,
                 (uint32_t)(result0 & 0xFFFFFFFFULL));

    /*
     * Store RESULT0 high 32 bits at RAM address 0x1234.
     */
    p5_ram_write(P5_DEBUG_RESULT0_HI,
                 (uint32_t)(result0 >> 32));

    /* ------------------------------------------------------------------------
     * Store RESULT1 in debug RAM
     * ---------------------------------------------------------------------- */

    /*
     * Store RESULT1 low 32 bits at RAM address 0x1238.
     */
    p5_ram_write(P5_DEBUG_RESULT1_LO,
                 (uint32_t)(result1 & 0xFFFFFFFFULL));

    /*
     * Store RESULT1 high 32 bits at RAM address 0x123C.
     */
    p5_ram_write(P5_DEBUG_RESULT1_HI,
                 (uint32_t)(result1 >> 32));

    /* ------------------------------------------------------------------------
     * Mark successful completion
     * ---------------------------------------------------------------------- */

    /*
     * This marker means:
     *
     *   1. TPU DONE was observed.
     *   2. RESULT0 was read.
     *   3. RESULT1 was read.
     *   4. Both results were stored in RAM.
     *   5. The elapsed cycle count was stored in RAM.
     *
     * The testbench must still compare the numerical result values separately.
     */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_SUCCESS);

    /* ------------------------------------------------------------------------
     * Terminal simulation state
     * ---------------------------------------------------------------------- */

    /*
     * Keep the CPU in a stable terminal state.
     *
     * This prevents the CPU from executing into unmapped memory or modifying
     * the debug RAM after the benchmark has completed.
     */
    while (1) {
        __asm__ volatile ("nop");
    }

    /*
     * This return is unreachable because of the terminal loop above.
     * It is retained to satisfy the C function's return type.
     */
    return 0;
}