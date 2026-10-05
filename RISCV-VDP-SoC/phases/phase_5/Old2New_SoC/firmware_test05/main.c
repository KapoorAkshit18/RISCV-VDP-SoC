#include <stdint.h>

/* ============================================================================
 * PHASE-5 FIRMWARE TEST 05
 *
 * Implements the following MATLAB network on the TPU:
 *
 *   k = [8, 8, 5, 5;
 *        8, 5, 8, 5]
 *
 *   wb2 = [1.37,  1.37, -19.88;
 *          0.77,  0.97,  -0.90;
 *          1.05,  0.64,  -0.89]
 *
 *   wb3 = [ 7.11, -1.31,  0.08, -2.59;
 *          -7.10,  1.63,  1.97,  0.20]
 *
 *   k_padded = cat(1, k, ones(1,4))       % append bias row
 *   z2 = wb2 * k_padded                   % 3x4
 *   a2 = sigmoid(z2)
 *   a2_padded = cat(1, a2, ones(1,4))     % append bias row
 *   z3 = wb3 * a2_padded                  % 2x4
 *   a3 = sigmoid(z3)
 *   a3_rounded = round(a3)
 *
 * Fixed-point format: Q5.10 (signed, 1 sign + 5 integer + 10 fractional bits)
 * Encoding: value_int = round(float * 1024) & 0xFFFF
 *
 * Register packing (64-bit = 4 x 16-bit):
 *   bits[15: 0] = w0   (first  element / column 0)
 *   bits[31:16] = w1   (second element / column 1)
 *   bits[47:32] = w2   (third  element / column 2)
 *   bits[63:48] = w3   (fourth element / column 3)
 *
 * AXI-Stream beat mapping:
 *   Beat 0 (weight0): wb2 row 0 = [ 1.37,  1.37, -19.88, 0 ]
 *   Beat 1 (weight1): wb2 row 1 = [ 0.77,  0.97,  -0.90, 0 ]
 *   Beat 2 (weight2): wb2 row 2 = [ 1.05,  0.64,  -0.89, 0 ]
 *   Beat 3 (weight3): wb3 row 0 = [ 7.11, -1.31,   0.08,-2.59 ]
 *   Beat 4 (weight4): wb3 row 1 = [-7.10,  1.63,   1.97, 0.20 ]
 *   Beat 5 (input0):  k   row 0 = [ 8,     8,      5,    5    ]
 *   Beat 6 (input1):  k   row 1 = [ 8,     5,      8,    5    ] + TLAST
 *
 * The bias rows (ones) in k_padded and a2_padded are handled by the weight
 * matrix last columns (wb2 col2 and wb3 col3 respectively).
 *
 * Expected output (float):
 *   a3[0] = [0.9933, 0.0003, 0.9933, 0.0003]
 *   a3[1] = [0.0067, 0.9997, 0.0067, 0.9997]
 *
 * Expected output (rounded):
 *   a3_rounded[0] = [1, 0, 1, 0]
 *   a3_rounded[1] = [0, 1, 0, 1]
 * ========================================================================== */

/* ============================================================================
 * TPU MEMORY MAP  (base 0x0001_4000)
 * ========================================================================== */

#define TPU_BASE            0x00014000u

#define TPU_CONTROL         0x0000u
#define TPU_STATUS          0x0004u

#define TPU_WEIGHT0_LO      0x0010u
#define TPU_WEIGHT0_HI      0x0014u
#define TPU_WEIGHT1_LO      0x0018u
#define TPU_WEIGHT1_HI      0x001Cu
#define TPU_WEIGHT2_LO      0x0020u
#define TPU_WEIGHT2_HI      0x0024u
#define TPU_WEIGHT3_LO      0x0028u
#define TPU_WEIGHT3_HI      0x002Cu
#define TPU_WEIGHT4_LO      0x0030u
#define TPU_WEIGHT4_HI      0x0034u
#define TPU_INPUT0_LO       0x0038u
#define TPU_INPUT0_HI       0x003Cu
#define TPU_INPUT1_LO       0x0040u
#define TPU_INPUT1_HI       0x0044u

#define TPU_RESULT0_LO      0x0050u
#define TPU_RESULT0_HI      0x0054u
#define TPU_RESULT1_LO      0x0058u
#define TPU_RESULT1_HI      0x005Cu

#define TPU_CONTROL_START   (1u << 0)
#define TPU_STATUS_BUSY     (1u << 0)
#define TPU_STATUS_DONE     (1u << 1)

/* ============================================================================
 * DEBUG RAM LOCATIONS
 * ========================================================================== */

#define DEBUG_RESULT0_LO    0x00001230u
#define DEBUG_RESULT0_HI    0x00001234u
#define DEBUG_RESULT1_LO    0x00001238u
#define DEBUG_RESULT1_HI    0x0000123Cu

#define DEBUG_CYCLES_LO     0x000012A0u
#define DEBUG_CYCLES_HI     0x000012A4u
#define DEBUG_MARKER        0x000012A8u

#define MARK_START          0x11111111u
#define MARK_DONE           0x22222222u
#define MARK_SUCCESS        0x33333333u
#define MARK_ERROR          0xDEAD0001u

#define TIMEOUT_COUNT       1000000u

/* ============================================================================
 * MMIO HELPERS
 * ========================================================================== */

static inline void mmio_write(uint32_t addr, uint32_t val)
{
    *(volatile uint32_t *)(uintptr_t)addr = val;
}

static inline uint32_t mmio_read(uint32_t addr)
{
    return *(volatile uint32_t *)(uintptr_t)addr;
}

static inline void tpu_write(uint32_t offset, uint32_t val)
{
    mmio_write(TPU_BASE + offset, val);
}

static inline uint32_t tpu_read(uint32_t offset)
{
    return mmio_read(TPU_BASE + offset);
}

static inline void tpu_write64(uint32_t lo_off, uint32_t hi_off, uint64_t val)
{
    tpu_write(lo_off, (uint32_t)(val & 0xFFFFFFFFULL));
    tpu_write(hi_off, (uint32_t)(val >> 32));
}

static inline uint64_t tpu_read64(uint32_t lo_off, uint32_t hi_off)
{
    return ((uint64_t)tpu_read(hi_off) << 32) | (uint64_t)tpu_read(lo_off);
}

static inline uint64_t read_cycle64(void)
{
    uint32_t hi1, lo, hi2;
    do {
        __asm__ volatile ("rdcycleh %0" : "=r"(hi1));
        __asm__ volatile ("rdcycle  %0" : "=r"(lo));
        __asm__ volatile ("rdcycleh %0" : "=r"(hi2));
    } while (hi1 != hi2);
    return ((uint64_t)hi2 << 32) | lo;
}

/* ============================================================================
 * MAIN
 * ========================================================================== */

int main(void)
{
    uint64_t start, end, elapsed;
    uint64_t result0, result1;
    uint32_t timeout;

    /* ------------------------------------------------------------------
     * Q5.10 encoded payloads
     *
     * pack64(w0, w1, w2, w3):
     *   bits[15: 0] = round(w0 * 1024) & 0xFFFF
     *   bits[31:16] = round(w1 * 1024) & 0xFFFF
     *   bits[47:32] = round(w2 * 1024) & 0xFFFF
     *   bits[63:48] = round(w3 * 1024) & 0xFFFF
     *
     * wb2 row 0: w0= 1.37 ->0x057B, w1= 1.37 ->0x057B, w2=-19.88->0xB07B, w3=0->0x0000
     * wb2 row 1: w0= 0.77 ->0x0315, w1= 0.97 ->0x03E2, w2= -0.90->0xFC66, w3=0->0x0000
     * wb2 row 2: w0= 1.05 ->0x0433, w1= 0.64 ->0x028F, w2= -0.89->0xFC70, w3=0->0x0000
     * wb3 row 0: w0= 7.11 ->0x1C71, w1=-1.31 ->0xFAC2, w2=  0.08->0x0052, w3=-2.59->0xF5A4
     * wb3 row 1: w0=-7.10 ->0xE31A, w1= 1.63 ->0x0685, w2=  1.97->0x07E1, w3= 0.20->0x00CD
     * k   row 0: w0= 8.0  ->0x2000, w1= 8.0  ->0x2000, w2=  5.0 ->0x1400, w3= 5.0 ->0x1400
     * k   row 1: w0= 8.0  ->0x2000, w1= 5.0  ->0x1400, w2=  8.0 ->0x2000, w3= 5.0 ->0x1400
     * ------------------------------------------------------------------ */

    const uint64_t weight0 = 0x0000B07B057B057BULL; /* wb2 row0:  1.37,  1.37, -19.88,  0.00 */
    const uint64_t weight1 = 0x0000FC6603E20315ULL; /* wb2 row1:  0.77,  0.97,  -0.90,  0.00 */
    const uint64_t weight2 = 0x0000FC70028F0433ULL; /* wb2 row2:  1.05,  0.64,  -0.89,  0.00 */
    const uint64_t weight3 = 0xF5A40052FAC21C71ULL; /* wb3 row0:  7.11, -1.31,   0.08, -2.59 */
    const uint64_t weight4 = 0x00CD07E10685E31AULL; /* wb3 row1: -7.10,  1.63,   1.97,  0.20 */
    const uint64_t input0  = 0x1400140020002000ULL; /* k   row0:  8.0,   8.0,    5.0,   5.0  */
    const uint64_t input1  = 0x1400200014002000ULL; /* k   row1:  8.0,   5.0,    8.0,   5.0  */

    /* Clear debug locations. */
    mmio_write(DEBUG_CYCLES_LO,  0u);
    mmio_write(DEBUG_CYCLES_HI,  0u);
    mmio_write(DEBUG_RESULT0_LO, 0u);
    mmio_write(DEBUG_RESULT0_HI, 0u);
    mmio_write(DEBUG_RESULT1_LO, 0u);
    mmio_write(DEBUG_RESULT1_HI, 0u);
    mmio_write(DEBUG_MARKER, MARK_START);

    start = read_cycle64();

    /* Load TPU registers. */
    tpu_write64(TPU_WEIGHT0_LO, TPU_WEIGHT0_HI, weight0);
    tpu_write64(TPU_WEIGHT1_LO, TPU_WEIGHT1_HI, weight1);
    tpu_write64(TPU_WEIGHT2_LO, TPU_WEIGHT2_HI, weight2);
    tpu_write64(TPU_WEIGHT3_LO, TPU_WEIGHT3_HI, weight3);
    tpu_write64(TPU_WEIGHT4_LO, TPU_WEIGHT4_HI, weight4);
    tpu_write64(TPU_INPUT0_LO,  TPU_INPUT0_HI,  input0);
    tpu_write64(TPU_INPUT1_LO,  TPU_INPUT1_HI,  input1);

    /* Issue START pulse. */
    tpu_write(TPU_CONTROL, TPU_CONTROL_START);

    /* Poll DONE. */
    timeout = 0u;
    while (timeout < TIMEOUT_COUNT) {
        if (tpu_read(TPU_STATUS) & TPU_STATUS_DONE)
            break;
        timeout++;
    }

    if (timeout >= TIMEOUT_COUNT) {
        end     = read_cycle64();
        elapsed = end - start;
        mmio_write(DEBUG_CYCLES_LO, (uint32_t)(elapsed & 0xFFFFFFFFULL));
        mmio_write(DEBUG_CYCLES_HI, (uint32_t)(elapsed >> 32));
        mmio_write(DEBUG_MARKER, MARK_ERROR);
        while (1) __asm__ volatile ("nop");
    }

    mmio_write(DEBUG_MARKER, MARK_DONE);

    /* Read results. */
    result0 = tpu_read64(TPU_RESULT0_LO, TPU_RESULT0_HI);
    result1 = tpu_read64(TPU_RESULT1_LO, TPU_RESULT1_HI);

    end     = read_cycle64();
    elapsed = end - start;

    mmio_write(DEBUG_CYCLES_LO,  (uint32_t)(elapsed  & 0xFFFFFFFFULL));
    mmio_write(DEBUG_CYCLES_HI,  (uint32_t)(elapsed  >> 32));
    mmio_write(DEBUG_RESULT0_LO, (uint32_t)(result0  & 0xFFFFFFFFULL));
    mmio_write(DEBUG_RESULT0_HI, (uint32_t)(result0  >> 32));
    mmio_write(DEBUG_RESULT1_LO, (uint32_t)(result1  & 0xFFFFFFFFULL));
    mmio_write(DEBUG_RESULT1_HI, (uint32_t)(result1  >> 32));
    mmio_write(DEBUG_MARKER, MARK_SUCCESS);

    while (1) __asm__ volatile ("nop");
    return 0;
}
