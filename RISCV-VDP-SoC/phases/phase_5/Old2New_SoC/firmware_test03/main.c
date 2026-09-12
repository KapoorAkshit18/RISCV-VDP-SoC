#include <stdint.h>

/* ============================================================================
 * PHASE-5 TPU MEMORY MAP
 * ========================================================================== */

#define TPU_BASE                0x00014000u

#define TPU_CONTROL             0x0000u
#define TPU_STATUS              0x0004u

#define TPU_WEIGHT0_LO          0x0010u
#define TPU_WEIGHT0_HI          0x0014u
#define TPU_WEIGHT1_LO          0x0018u
#define TPU_WEIGHT1_HI          0x001Cu
#define TPU_WEIGHT2_LO          0x0020u
#define TPU_WEIGHT2_HI          0x0024u
#define TPU_WEIGHT3_LO          0x0028u
#define TPU_WEIGHT3_HI          0x002Cu
#define TPU_WEIGHT4_LO          0x0030u
#define TPU_WEIGHT4_HI          0x0034u
#define TPU_INPUT0_LO           0x0038u
#define TPU_INPUT0_HI           0x003Cu
#define TPU_INPUT1_LO           0x0040u
#define TPU_INPUT1_HI           0x0044u

#define TPU_RESULT0_LO          0x0050u
#define TPU_RESULT0_HI          0x0054u
#define TPU_RESULT1_LO          0x0058u
#define TPU_RESULT1_HI          0x005Cu

#define TPU_CONTROL_START       (1u << 0)
#define TPU_STATUS_BUSY         (1u << 0)
#define TPU_STATUS_DONE         (1u << 1)

/* ============================================================================
 * DEBUG RAM LOCATIONS
 * ========================================================================== */

#define DEBUG_RESULT0_LO        0x00001230u
#define DEBUG_RESULT0_HI        0x00001234u
#define DEBUG_RESULT1_LO        0x00001238u
#define DEBUG_RESULT1_HI        0x0000123Cu

#define DEBUG_CYCLES_LO         0x000012A0u
#define DEBUG_CYCLES_HI         0x000012A4u
#define DEBUG_MARKER            0x000012A8u

#define MARK_START              0x11111111u
#define MARK_DONE               0x22222222u
#define MARK_SUCCESS            0x33333333u
#define MARK_ERROR              0xDEAD0001u

#define TIMEOUT_COUNT           1000000u

/* ============================================================================
 * MMIO ACCESS
 * ========================================================================== */

static inline void mmio_write(uint32_t address, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)address = value;
}

static inline uint32_t mmio_read(uint32_t address)
{
    return *(volatile uint32_t *)(uintptr_t)address;
}

static inline void tpu_write(uint32_t offset, uint32_t value)
{
    mmio_write(TPU_BASE + offset, value);
}

static inline uint32_t tpu_read(uint32_t offset)
{
    return mmio_read(TPU_BASE + offset);
}

static inline void debug_write(uint32_t address, uint32_t value)
{
    mmio_write(address, value);
}

/* ============================================================================
 * 64-BIT REGISTER ACCESS USING RV32 32-BIT TRANSACTIONS
 * ========================================================================== */

static inline void tpu_write64(uint32_t lo_offset,
                               uint32_t hi_offset,
                               uint64_t value)
{
    uint32_t lo = (uint32_t)(value & 0xFFFFFFFFULL);
    uint32_t hi = (uint32_t)(value >> 32);

    tpu_write(lo_offset, lo);
    tpu_write(hi_offset, hi);
}

static inline uint64_t tpu_read64(uint32_t lo_offset,
                                  uint32_t hi_offset)
{
    uint32_t lo = tpu_read(lo_offset);
    uint32_t hi = tpu_read(hi_offset);

    return ((uint64_t)hi << 32) | (uint64_t)lo;
}

/* ============================================================================
 * RV32 CYCLE COUNTER
 * ========================================================================== */

static inline uint64_t read_cycle64(void)
{
    uint32_t hi_first;
    uint32_t lo;
    uint32_t hi_second;

    do {
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_first));
        __asm__ volatile ("rdcycle %0"  : "=r"(lo));
        __asm__ volatile ("rdcycleh %0" : "=r"(hi_second));
    } while (hi_first != hi_second);

    return ((uint64_t)hi_second << 32) | (uint64_t)lo;
}

/* ============================================================================
 * MAIN PHASE-5 BENCHMARK
 * ========================================================================== */

int main(void)
{
    uint64_t start_cycles;
    uint64_t end_cycles;
    uint64_t elapsed_cycles;
    uint64_t result0;
    uint64_t result1;
    uint32_t timeout;

    /*
     * AXI-Stream payloads:
     *
     * Beat 0: WEIGHT0
     * Beat 1: WEIGHT1
     * Beat 2: WEIGHT2
     * Beat 3: WEIGHT3
     * Beat 4: WEIGHT4
     * Beat 5: INPUT0
     * Beat 6: INPUT1 with TLAST
     */
    const uint64_t weight0 = 0x0000B07A0505057AULL;
    const uint64_t weight1 = 0x0000FC6603E10314ULL;
    const uint64_t weight2 = 0x0000FC70028F0433ULL;
    const uint64_t weight3 = 0xF5A30051FAC21870ULL;
    const uint64_t weight4 = 0x00CC07E10685E399ULL;
    const uint64_t input0  = 0x1400140020002000ULL;
    const uint64_t input1  = 0x1400200014002000ULL;

    /* Clear debug locations before starting. */
    debug_write(DEBUG_CYCLES_LO, 0u);
    debug_write(DEBUG_CYCLES_HI, 0u);
    debug_write(DEBUG_RESULT0_LO, 0u);
    debug_write(DEBUG_RESULT0_HI, 0u);
    debug_write(DEBUG_RESULT1_LO, 0u);
    debug_write(DEBUG_RESULT1_HI, 0u);

    /* Mark firmware entry. */
    debug_write(DEBUG_MARKER, MARK_START);

    /* Start timing before TPU configuration. */
    start_cycles = read_cycle64();

    /* Configure TPU input registers. */
    tpu_write64(TPU_WEIGHT0_LO, TPU_WEIGHT0_HI, weight0);
    tpu_write64(TPU_WEIGHT1_LO, TPU_WEIGHT1_HI, weight1);
    tpu_write64(TPU_WEIGHT2_LO, TPU_WEIGHT2_HI, weight2);
    tpu_write64(TPU_WEIGHT3_LO, TPU_WEIGHT3_HI, weight3);
    tpu_write64(TPU_WEIGHT4_LO, TPU_WEIGHT4_HI, weight4);
    tpu_write64(TPU_INPUT0_LO,  TPU_INPUT0_HI,  input0);
    tpu_write64(TPU_INPUT1_LO,  TPU_INPUT1_HI,  input1);

    /* Issue one-cycle START command. */
    tpu_write(TPU_CONTROL, TPU_CONTROL_START);

    /* Wait until TPU reports DONE or timeout occurs. */
    timeout = 0u;

    while (timeout < TIMEOUT_COUNT) {
        uint32_t status = tpu_read(TPU_STATUS);

        if ((status & TPU_STATUS_DONE) != 0u) {
            break;
        }

        timeout++;
    }

    /* Handle TPU timeout. */
    if (timeout >= TIMEOUT_COUNT) {
        end_cycles = read_cycle64();
        elapsed_cycles = end_cycles - start_cycles;

        debug_write(DEBUG_CYCLES_LO,
                    (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));
        debug_write(DEBUG_CYCLES_HI,
                    (uint32_t)(elapsed_cycles >> 32));

        debug_write(DEBUG_MARKER, MARK_ERROR);

        while (1) {
            __asm__ volatile ("nop");
        }
    }

    /* Mark TPU completion observed. */
    debug_write(DEBUG_MARKER, MARK_DONE);

    /* Read both 64-bit TPU results. */
    result0 = tpu_read64(TPU_RESULT0_LO, TPU_RESULT0_HI);
    result1 = tpu_read64(TPU_RESULT1_LO, TPU_RESULT1_HI);

    /* Stop timing after result reads. */
    end_cycles = read_cycle64();
    elapsed_cycles = end_cycles - start_cycles;

    /* Store elapsed cycle count. */
    debug_write(DEBUG_CYCLES_LO,
                (uint32_t)(elapsed_cycles & 0xFFFFFFFFULL));
    debug_write(DEBUG_CYCLES_HI,
                (uint32_t)(elapsed_cycles >> 32));

    /* Store RESULT0. */
    debug_write(DEBUG_RESULT0_LO,
                (uint32_t)(result0 & 0xFFFFFFFFULL));
    debug_write(DEBUG_RESULT0_HI,
                (uint32_t)(result0 >> 32));

    /* Store RESULT1. */
    debug_write(DEBUG_RESULT1_LO,
                (uint32_t)(result1 & 0xFFFFFFFFULL));
    debug_write(DEBUG_RESULT1_HI,
                (uint32_t)(result1 >> 32));

    /* Mark successful completion. */
    debug_write(DEBUG_MARKER, MARK_SUCCESS);

    /* Hold CPU in a stable terminal state. */
    while (1) {
        __asm__ volatile ("nop");
    }

    return 0;
}