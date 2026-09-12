/* ============================================================================
 * RISCV-VDP-SoC PHASE-5 STARTUP
 * ========================================================================== */

.section .text.start
.global _start
.type _start, @function

_start:
    /* Initialize stack pointer at the top of 64-KB RAM. */
    li sp, 0x00010000

    /* Initialize global pointer if small-data sections are used. */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Clear frame pointer. */
    li s0, 0

    /* Call C entry point. */
    call main

1:
    /* Safety loop if main ever returns. */
    j 1b

.size _start, .-_start