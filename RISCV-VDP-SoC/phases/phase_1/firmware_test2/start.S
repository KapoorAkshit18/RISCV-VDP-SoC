/*
 * ============================================================
 * RISC-V SoC Firmware Startup
 * ============================================================
 *
 * Purpose:
 *   Minimal bare-metal startup code for the RISC-V CPU.
 *
 * Flow:
 *
 *   Reset
 *     |
 *     v
 *   _start
 *     |
 *     +--> Initialize stack pointer
 *     |
 *     +--> Call main()
 *     |
 *     v
 *   Infinite loop
 *
 * No operating system or C runtime is used.
 * ============================================================
 */

.section .text
.global _start
.type _start, @function

_start:

    /*
     * --------------------------------------------------------
     * Initialize stack pointer
     * --------------------------------------------------------
     *
     * Stack grows downward.
     *
     * Assuming the available RAM ends at 0x00010000,
     * use the top of RAM as the initial stack pointer.
     */
    li sp, 0x00010000

    /*
     * --------------------------------------------------------
     * Call the C application
     * --------------------------------------------------------
     *
     * main() contains the actual matrix-vector multiplication
     * benchmark.
     */
    call main

    /*
     * --------------------------------------------------------
     * main() should never normally return.
     *
     * Keep the CPU here if it does.
     * --------------------------------------------------------
     */
1:
    j 1b

.size _start, .-_start
