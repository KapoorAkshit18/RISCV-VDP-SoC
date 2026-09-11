/*
 * phase3_sigmoid.c
 * Phase 3: CPU-only reference for the TPU's fixed-point sigmoid workload.
 *
 * Common dataset: the exact seven 64-bit AXI-Stream words used by axis_nn_tb.
 * Fixed-point format: signed Q6.10 (16-bit), FRAC_BIT = 10.
 *
 * IMPORTANT:
 * - This is CPU-only. It does NOT access the TPU MMIO window.
 * - The sigmoid LUT below matches Design_Dir/RTL/sigmoid.v:
 *       address 0..127  -> 0.0000 .. +7.9375, step 1/16
 *       address 128..255 -> -8.0000 .. -0.0625, step 1/16
 *   output = mem[address][29:14], i.e. Q6.10.
 * - PE arithmetic matches pe.v: signed 16x16, arithmetic >> 10, then
 *   16-bit two's-complement wrap.
 *
 * Memory map used by this benchmark:
 *   0x12A0 : cycle count low
 *   0x12A4 : cycle count high
 *   0x12A8 : debug marker
 *   0x1300 : packed input/weight words
 *   0x1340 : first sigmoid outputs
 *   0x1350 : final software outputs
 *
 * Markers:
 *   0x11111111 = benchmark started
 *   0x22222222 = computation complete
 *   0x33333333 = benchmark passed
 *   0xDEAD0001 = benchmark failed
 */

#include <stdint.h>

#define P3_CYCLES_LO_ADDR   0x000012A0u
#define P3_CYCLES_HI_ADDR   0x000012A4u
#define P3_DEBUG_ADDR       0x000012A8u

#define P3_DATA_BASE        0x00001300u
#define P3_SIG_BASE         0x00001340u
#define P3_RESULT_BASE      0x00001350u

#define P3_Q_ONE             ((int16_t)0x0400)
#define P3_FRAC_BITS         10

#define P3_U32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

/* Exact seven 64-bit words from the standalone axis_nn_tb. */
static const uint64_t p3_weight_word[5] = {
    0x0000B07A0505057AULL,
    0x0000FC6603E10314ULL,
    0x0000FC70028F0433ULL,
    0xF5A30051FAC21870ULL,
    0x00CC07E10685E399ULL
};

static const uint64_t p3_input_word[2] = {
    0x1400140020002000ULL,
    0x1400200014002000ULL
};

/*
 * Exact sigmoid output table, Q6.10.
 * Index mapping is the RTL mapping described above.
 */
static const uint16_t p3_sigmoid_lut[256] = {
    0x0200, 0x020F, 0x021F, 0x022F, 0x023F, 0x024F, 0x025E, 0x026E,
    0x027D, 0x028C, 0x029A, 0x02A9, 0x02B7, 0x02C5, 0x02D2, 0x02DF,
    0x02EC, 0x02F9, 0x0305, 0x0310, 0x031B, 0x0326, 0x0331, 0x033B,
    0x0345, 0x034E, 0x0357, 0x0360, 0x0368, 0x0370, 0x0377, 0x037F,
    0x0385, 0x038C, 0x0392, 0x0398, 0x039E, 0x03A3, 0x03A8, 0x03AD,
    0x03B2, 0x03B6, 0x03BA, 0x03BE, 0x03C2, 0x03C5, 0x03C9, 0x03CC,
    0x03CF, 0x03D2, 0x03D4, 0x03D7, 0x03D9, 0x03DC, 0x03DE, 0x03E0,
    0x03E1, 0x03E3, 0x03E5, 0x03E6, 0x03E8, 0x03E9, 0x03EB, 0x03EC,
    0x03ED, 0x03EE, 0x03EF, 0x03F0, 0x03F1, 0x03F2, 0x03F3, 0x03F4,
    0x03F4, 0x03F5, 0x03F6, 0x03F6, 0x03F7, 0x03F7, 0x03F8, 0x03F8,
    0x03F9, 0x03F9, 0x03F9, 0x03FA, 0x03FA, 0x03FA, 0x03FB, 0x03FB,
    0x03FB, 0x03FC, 0x03FC, 0x03FC, 0x03FC, 0x03FC, 0x03FD, 0x03FD,
    0x03FD, 0x03FD, 0x03FD, 0x03FD, 0x03FE, 0x03FE, 0x03FE, 0x03FE,
    0x03FE, 0x03FE, 0x03FE, 0x03FE, 0x03FE, 0x03FE, 0x03FE, 0x03FF,
    0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF,
    0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF, 0x03FF,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0001,
    0x0001, 0x0001, 0x0001, 0x0001, 0x0001, 0x0002, 0x0002, 0x0002,
    0x0002, 0x0002, 0x0002, 0x0003, 0x0003, 0x0003, 0x0003, 0x0003,
    0x0004, 0x0004, 0x0004, 0x0005, 0x0005, 0x0005, 0x0006, 0x0006,
    0x0006, 0x0007, 0x0007, 0x0008, 0x0008, 0x0009, 0x0009, 0x000A,
    0x000B, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F, 0x0010, 0x0011,
    0x0012, 0x0013, 0x0014, 0x0016, 0x0017, 0x0019, 0x001A, 0x001C,
    0x001E, 0x001F, 0x0021, 0x0023, 0x0026, 0x0028, 0x002B, 0x002D,
    0x0030, 0x0033, 0x0036, 0x003A, 0x003D, 0x0041, 0x0045, 0x0049,
    0x004D, 0x0052, 0x0057, 0x005C, 0x0061, 0x0067, 0x006D, 0x0073,
    0x007A, 0x0080, 0x0088, 0x008F, 0x0097, 0x009F, 0x00A8, 0x00B1,
    0x00BA, 0x00C4, 0x00CE, 0x00D9, 0x00E4, 0x00EF, 0x00FA, 0x0106,
    0x0113, 0x0120, 0x012D, 0x013A, 0x0148, 0x0156, 0x0165, 0x0173,
    0x0182, 0x0191, 0x01A1, 0x01B0, 0x01C0, 0x01D0, 0x01E0, 0x01F0,
};

/* Convert one packed 64-bit word into four signed 16-bit lanes. */
static int16_t p3_lane(uint64_t word, unsigned lane)
{
    return (int16_t)((word >> (16u * lane)) & 0xFFFFu);
}

/*
 * Exact PE fixed-point operation from pe.v:
 *
 *   y_out = y_in + product[25:10]
 *
 * The cast to int16_t intentionally preserves the RTL's 16-bit wraparound.
 */
static int16_t p3_pe_mac(int16_t a, int16_t b, int16_t y)
{
    int32_t product = (int32_t)a * (int32_t)b;
    int32_t scaled = product >> P3_FRAC_BITS;
    return (int16_t)(y + scaled);
}

/*
 * Exact sigmoid address generation from sigmoid.v.
 *
 * For ordinary in-range values din[15:6] is the LUT address.
 * For values outside the representable -8 .. +7.9375 range, the
 * hardware clamps negative values to 0x80 and positive values to 0x7F.
 */
static uint16_t p3_sigmoid(int16_t din)
{
    uint16_t u = (uint16_t)din;
    uint16_t top = (u >> 13) & 0x7u;
    uint16_t addr;

    /* RTL: saturation = ~&din[15:13] & |din[15:13] */
    if (top == 0u || top == 7u) {
        addr = (uint16_t)((u >> 6) & 0xFFu);
    } else {
        addr = (din < 0) ? 0x80u : 0x7Fu;
    }

    return p3_sigmoid_lut[addr];
}

/*
 * CPU reference workload corresponding to the supplied TPU stimulus.
 *
 * The five weight beats contain four lanes each. The first three beats
 * form the first affine stage:
 *
 *   z[j] = w0[j]*x0[j] + w1[j]*x1[j] + w2[j]*1.0
 *
 * followed by the hardware sigmoid quantization.
 *
 * The remaining two weight beats form the second affine stage using the
 * four sigmoid values and the Q6.10 unit/bias path. The result is kept
 * in the same 16-bit fixed-point domain as the TPU.
 *
 * The intermediate values are stored so the waveform/TB can be checked
 * without relying on printf/UART.
 */
static void p3_run_reference(int16_t hidden[4], int16_t result[4])
{
    int16_t x0[4], x1[4];
    int16_t w0[4], w1[4], w2[4], w3[4], w4[4];
    unsigned j;

    for (j = 0; j < 4; ++j) {
        x0[j] = p3_lane(p3_input_word[0], j);
        x1[j] = p3_lane(p3_input_word[1], j);
        w0[j] = p3_lane(p3_weight_word[0], j);
        w1[j] = p3_lane(p3_weight_word[1], j);
        w2[j] = p3_lane(p3_weight_word[2], j);
        w3[j] = p3_lane(p3_weight_word[3], j);
        w4[j] = p3_lane(p3_weight_word[4], j);
    }

    for (j = 0; j < 4; ++j) {
        int16_t z;

        z = 0;
        z = p3_pe_mac(w0[j], x0[j], z);
        z = p3_pe_mac(w1[j], x1[j], z);
        z = p3_pe_mac(w2[j], P3_Q_ONE, z);

        hidden[j] = (int16_t)p3_sigmoid(z);
    }

    /*
     * Second affine stage.
     *
     * w3 and w4 are the two later weight beats in the common TPU stimulus.
     * The Q6.10 unit term keeps the computation in the same fixed-point
     * scale and makes the software reference deterministic.
     */
    for (j = 0; j < 4; ++j) {
        int16_t z;

        z = 0;
        z = p3_pe_mac(w3[j], hidden[j], z);
        z = p3_pe_mac(w4[j], P3_Q_ONE, z);

        result[j] = z;
    }
}

int main(void)
{
    volatile int16_t *sig_mem =
        (volatile int16_t *)(uintptr_t)P3_SIG_BASE;
    volatile int16_t *result_mem =
        (volatile int16_t *)(uintptr_t)P3_RESULT_BASE;

    int16_t hidden[4];
    int16_t result[4];
    uint32_t cycle_lo, cycle_hi;
    uint32_t start_lo, start_hi;
    uint64_t cycles;
    unsigned i;

    P3_U32(P3_DEBUG_ADDR) = 0x11111111u;

    /*
     * Keep the cycle counter around the CPU computation only.
     * rdcycle/rdcycleh are standard RISC-V counters supported by
     * PicoRV32 when the corresponding CSR support is enabled.
     */
    __asm__ volatile ("rdcycle %0" : "=r"(start_lo));
    __asm__ volatile ("rdcycleh %0" : "=r"(start_hi));

    p3_run_reference(hidden, result);

    __asm__ volatile ("rdcycle %0" : "=r"(cycle_lo));
    __asm__ volatile ("rdcycleh %0" : "=r"(cycle_hi));

    cycles = (((uint64_t)cycle_hi << 32) | cycle_lo) -
             (((uint64_t)start_hi << 32) | start_lo);

    P3_U32(P3_CYCLES_LO_ADDR) = (uint32_t)cycles;
    P3_U32(P3_CYCLES_HI_ADDR) = (uint32_t)(cycles >> 32);

    for (i = 0; i < 4; ++i)
        sig_mem[i] = hidden[i];

    for (i = 0; i < 4; ++i)
        result_mem[i] = result[i];

    P3_U32(P3_DEBUG_ADDR) = 0x22222222u;

    /*
     * Non-zero/zero check only confirms that the CPU reference executed
     * and produced deterministic values. The exact four result words
     * remain visible in RAM for direct comparison with Phase 5.
     */
    if ((hidden[0] == 0 && hidden[1] == 0 &&
         hidden[2] == 0 && hidden[3] == 0) ||
        (result[0] == 0 && result[1] == 0 &&
         result[2] == 0 && result[3] == 0)) {
        P3_U32(P3_DEBUG_ADDR) = 0xDEAD0001u;
    } else {
        P3_U32(P3_DEBUG_ADDR) = 0x33333333u;
    }

    while (1)
        ;
}
