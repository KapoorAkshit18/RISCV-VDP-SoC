/*
 * ============================================================================
 * RISCV-VDP-SoC - Phase 5 Firmware
 * ============================================================================
 *
 * Purpose:
 *   CPU-driven TPU/NN accelerator benchmark.
 *
 * Comparison basis:
 *   Phase 3 = CPU-only software implementation of the same fixed-point
 *             sigmoid workload.
 *   Phase 5 = CPU configures the integrated TPU through its MMIO register
 *             interface, starts the TPU, waits for completion, and reads back
 *             the two 64-bit result words.
 *
 * TPU system base:
 *   0x0001_4000
 *
 * TPU register map (from nn_axi_wrapper.v):
 *   CONTROL   0x00   bit 0 = START (one-cycle write pulse)
 *   STATUS    0x04   bit 0 = BUSY
 *                      bit 1 = DONE
 *
 *   WEIGHT0   0x10 / 0x14   low / high 32 bits
 *   WEIGHT1   0x18 / 0x1C
 *   WEIGHT2   0x20 / 0x24
 *   WEIGHT3   0x28 / 0x2C
 *   WEIGHT4   0x30 / 0x34
 *   INPUT0    0x38 / 0x3C
 *   INPUT1    0x40 / 0x44
 *
 *   RESULT0   0x50 / 0x54
 *   RESULT1   0x58 / 0x5C
 *
 * AXI-Stream payload:
 *   beat 0 = weight0
 *   beat 1 = weight1
 *   beat 2 = weight2
 *   beat 3 = weight3
 *   beat 4 = weight4
 *   beat 5 = input0
 *   beat 6 = input1 + TLAST
 *
 * The seven 64-bit payloads below are intentionally identical to the
 * standalone axis_nn_tb stimulus used for the TPU.
 *
 * Benchmark timing:
 *   The cycle counter starts immediately before the TPU MMIO configuration
 *   and ends after both result words have been read.
 *
 * Debug RAM locations:
 *   0x12A0 = cycle count low 32 bits
 *   0x12A4 = cycle count high 32 bits
 *   0x12A8 = status marker
 *             0x11111111 = benchmark started
 *             0x22222222 = TPU DONE observed
 *             0x33333333 = results read successfully
 *             0xDEAD0001 = timeout/error
 *
 * Result/debug area:
 *   0x1230 = RESULT0 low
 *   0x1234 = RESULT0 high
 *   0x1238 = RESULT1 low
 *   0x123C = RESULT1 high
 *
 * NOTE:
 *   The firmware does not contain the sigmoid LUT. The sigmoid operation is
 *   performed by the integrated TPU sigmoid hardware. Phase 3 contains the
 *   software reference/LUT.
 *
 * Bare-metal RV32I compatible:
 *   Only 32-bit volatile MMIO accesses and rdcycle/rdcycleh are used.
 * ============================================================================
 */

#include <stdint.h>

/* --------------------------------------------------------------------------
 * TPU base address
 * -------------------------------------------------------------------------- */
#define P5_TPU_BASE        0x00014000u

/* --------------------------------------------------------------------------
 * TPU register offsets
 * -------------------------------------------------------------------------- */
#define P5_REG_CONTROL     0x0000u
#define P5_REG_STATUS      0x0004u

#define P5_REG_WEIGHT0_LO  0x0010u
#define P5_REG_WEIGHT0_HI  0x0014u
#define P5_REG_WEIGHT1_LO  0x0018u
#define P5_REG_WEIGHT1_HI  0x001Cu
#define P5_REG_WEIGHT2_LO  0x0020u
#define P5_REG_WEIGHT2_HI  0x0024u
#define P5_REG_WEIGHT3_LO  0x0028u
#define P5_REG_WEIGHT3_HI  0x002Cu
#define P5_REG_WEIGHT4_LO  0x0030u
#define P5_REG_WEIGHT4_HI  0x0034u

#define P5_REG_INPUT0_LO   0x0038u
#define P5_REG_INPUT0_HI   0x003Cu
#define P5_REG_INPUT1_LO   0x0040u
#define P5_REG_INPUT1_HI   0x0044u

#define P5_REG_RESULT0_LO  0x0050u
#define P5_REG_RESULT0_HI  0x0054u
#define P5_REG_RESULT1_LO  0x0058u
#define P5_REG_RESULT1_HI  0x005Cu

/* --------------------------------------------------------------------------
 * STATUS bits
 * -------------------------------------------------------------------------- */
#define P5_STATUS_BUSY     (1u << 0)
#define P5_STATUS_DONE     (1u << 1)

/* --------------------------------------------------------------------------
 * CONTROL bits
 * -------------------------------------------------------------------------- */
#define P5_CONTROL_START   (1u << 0)

/* --------------------------------------------------------------------------
 * Debug RAM addresses
 * -------------------------------------------------------------------------- */
#define P5_DEBUG_CYCLES_LO 0x000012A0u
#define P5_DEBUG_CYCLES_HI 0x000012A4u
#define P5_DEBUG_MARKER    0x000012A8u

#define P5_DEBUG_RESULT0_LO 0x00001230u
#define P5_DEBUG_RESULT0_HI 0x00001234u
#define P5_DEBUG_RESULT1_LO 0x00001238u
#define P5_DEBUG_RESULT1_HI 0x0000123Cu

#define P5_MARK_START      0x11111111u
#define P5_MARK_DONE       0x22222222u
#define P5_MARK_SUCCESS    0x33333333u
#define P5_MARK_ERROR      0xDEAD0001u

/*
 * Large enough for simulation, while still guaranteeing that a broken
 * accelerator cannot leave the CPU polling forever.
 *
 * Increase only if a deliberately slower simulation requires it.
 */
#define P5_TIMEOUT_COUNT   1000000u

/* --------------------------------------------------------------------------
 * 32-bit volatile access helpers
 * -------------------------------------------------------------------------- */
static inline void p5_mmio_write(uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)(P5_TPU_BASE + offset) = value;
}

static inline uint32_t p5_mmio_read(uint32_t offset)
{
    return *(volatile uint32_t *)(P5_TPU_BASE + offset);
}

static inline void p5_ram_write(uint32_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

/* --------------------------------------------------------------------------
 * Write one 64-bit TPU register using two 32-bit CPU MMIO transactions.
 * -------------------------------------------------------------------------- */
static inline void p5_write64(uint32_t lo_offset,
                              uint32_t hi_offset,
                              uint64_t value)
{
    p5_mmio_write(lo_offset, (uint32_t)(value & 0xFFFFFFFFULL));
    p5_mmio_write(hi_offset, (uint32_t)(value >> 32));
}

/* --------------------------------------------------------------------------
 * Read one 64-bit TPU result using two 32-bit CPU MMIO transactions.
 * -------------------------------------------------------------------------- */
static inline uint64_t p5_read64(uint32_t lo_offset,
                                 uint32_t hi_offset)
{
    uint32_t lo = p5_mmio_read(lo_offset);
    uint32_t hi = p5_mmio_read(hi_offset);

    return ((uint64_t)hi << 32) | (uint64_t)lo;
}

/* --------------------------------------------------------------------------
 * Read the RISC-V cycle counter.
 *
 * The high word is read, followed by low, followed by high again. This
 * avoids returning a corrupted 64-bit value if mcycle crosses 0xFFFFFFFF
 * between the two reads.
 * -------------------------------------------------------------------------- */
static inline uint64_t p5_rdcycle64(void)
{
    uint32_t hi_a;
    uint32_t lo;
    uint32_t hi_b;

    do {
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_a));
        __asm__ volatile ("rdcycle  %0" : "=r"(lo));
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_b));
    } while (hi_a != hi_b);

    return ((uint64_t)hi_b << 32) | (uint64_t)lo;
}

/* --------------------------------------------------------------------------
 * Exact seven 64-bit payloads from the standalone TPU testbench.
 *
 * Each word contains four signed 16-bit values:
 *   bits [15:0]   = lane 0
 *   bits [31:16]  = lane 1
 *   bits [47:32]  = lane 2
 *   bits [63:48]  = lane 3
 *
 * They are kept as uint64_t because the TPU register interface is bit-exact.
 * -------------------------------------------------------------------------- */
static const uint64_t P5_WEIGHT0 = 0x0000B07A0505057AULL;
static const uint64_t P5_WEIGHT1 = 0x0000FC6603E10314ULL;
static const uint64_t P5_WEIGHT2 = 0x0000FC70028F0433ULL;
static const uint64_t P5_WEIGHT3 = 0xF5A30051FAC21870ULL;
static const uint64_t P5_WEIGHT4 = 0x00CC07E10685E399ULL;

static const uint64_t P5_INPUT0  = 0x1400140020002000ULL;
static const uint64_t P5_INPUT1  = 0x1400200014002000ULL;

/* --------------------------------------------------------------------------
 * Main benchmark
 * -------------------------------------------------------------------------- */
int main(void)
{
    uint64_t start_cycles;
    uint64_t end_cycles;
    uint64_t elapsed_cycles;

    uint64_t result0;
    uint64_t result1;

    uint32_t status;
    uint32_t timeout = 0;

    /* --------------------------------------------------------------
     * Mark benchmark entry.
     * -------------------------------------------------------------- */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_START);

    /* --------------------------------------------------------------
     * Start timing.
     *
     * This intentionally includes:
     *   1. CPU -> TPU weight/input MMIO writes
     *   2. TPU START write
     *   3. TPU execution
     *   4. CPU polling/synchronization
     *   5. TPU result MMIO reads
     *
     * This is the appropriate Phase-5 end-to-end accelerator-offload
     * measurement when compared with a CPU-only Phase-3 implementation.
     * -------------------------------------------------------------- */
    start_cycles = p5_rdcycle64();

    /* --------------------------------------------------------------
     * Load exactly the same seven payloads used by the TPU standalone TB.
     * -------------------------------------------------------------- */
    p5_write64(P5_REG_WEIGHT0_LO, P5_REG_WEIGHT0_HI, P5_WEIGHT0);
    p5_write64(P5_REG_WEIGHT1_LO, P5_REG_WEIGHT1_HI, P5_WEIGHT1);
    p5_write64(P5_REG_WEIGHT2_LO, P5_REG_WEIGHT2_HI, P5_WEIGHT2);
    p5_write64(P5_REG_WEIGHT3_LO, P5_REG_WEIGHT3_HI, P5_WEIGHT3);
    p5_write64(P5_REG_WEIGHT4_LO, P5_REG_WEIGHT4_HI, P5_WEIGHT4);

    p5_write64(P5_REG_INPUT0_LO,  P5_REG_INPUT0_HI,  P5_INPUT0);
    p5_write64(P5_REG_INPUT1_LO,  P5_REG_INPUT1_HI,  P5_INPUT1);

    /* --------------------------------------------------------------
     * START is a one-cycle command in the TPU wrapper.
     *
     * The RTL accepts START only when axis_busy is low.
     * -------------------------------------------------------------- */
    p5_mmio_write(P5_REG_CONTROL, P5_CONTROL_START);

    /* --------------------------------------------------------------
     * Poll until TPU reports DONE.
     *
     * The timeout is only a safety mechanism for simulation/debugging.
     * It is not part of the measured successful latency.
     * -------------------------------------------------------------- */
    while (1) {
        status = p5_mmio_read(P5_REG_STATUS);

        if ((status & P5_STATUS_DONE) != 0u) {
            break;
        }

        timeout++;

        if (timeout >= P5_TIMEOUT_COUNT) {
            /*
             * Record failure before entering the terminal loop.
             * The cycle count is still recorded so a failed simulation
             * can be diagnosed from RAM.
             */
            end_cycles = p5_rdcycle64();
            elapsed_cycles = end_cycles - start_cycles;

            p5_ram_write(P5_DEBUG_CYCLES_LO,
                         (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));
            p5_ram_write(P5_DEBUG_CYCLES_HI,
                         (uint32_t)(elapsed_cycles >> 32));

            p5_ram_write(P5_DEBUG_MARKER, P5_MARK_ERROR);

            while (1) {
                __asm__ volatile ("nop");
            }
        }
    }

    /* --------------------------------------------------------------
     * DONE observed.
     * -------------------------------------------------------------- */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_DONE);

    /* --------------------------------------------------------------
     * Read the two 64-bit TPU result words.
     * -------------------------------------------------------------- */
    result0 = p5_read64(P5_REG_RESULT0_LO, P5_REG_RESULT0_HI);
    result1 = p5_read64(P5_REG_RESULT1_LO, P5_REG_RESULT1_HI);

    /* --------------------------------------------------------------
     * Stop timing after result reads.
     * -------------------------------------------------------------- */
    end_cycles = p5_rdcycle64();
    elapsed_cycles = end_cycles - start_cycles;

    /* --------------------------------------------------------------
     * Save benchmark result in RAM for the SystemVerilog testbench.
     * -------------------------------------------------------------- */
    p5_ram_write(P5_DEBUG_CYCLES_LO,
                 (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));
    p5_ram_write(P5_DEBUG_CYCLES_HI,
                 (uint32_t)(elapsed_cycles >> 32));

    /* Save both 64-bit accelerator result words. */
    p5_ram_write(P5_DEBUG_RESULT0_LO,
                 (uint32_t)(result0 & 0xFFFFFFFFULL));
    p5_ram_write(P5_DEBUG_RESULT0_HI,
                 (uint32_t)(result0 >> 32));

    p5_ram_write(P5_DEBUG_RESULT1_LO,
                 (uint32_t)(result1 & 0xFFFFFFFFULL));
    p5_ram_write(P5_DEBUG_RESULT1_HI,
                 (uint32_t)(result1 >> 32));

    /* --------------------------------------------------------------
     * Successful completion marker.
     * -------------------------------------------------------------- */
    p5_ram_write(P5_DEBUG_MARKER, P5_MARK_SUCCESS);

    /* --------------------------------------------------------------
     * Terminal state for simulation.
     * -------------------------------------------------------------- */
    while (1) {
        __asm__ volatile ("nop");
    }

    return 0;
}
