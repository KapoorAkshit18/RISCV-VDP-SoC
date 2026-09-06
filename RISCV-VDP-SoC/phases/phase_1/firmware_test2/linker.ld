/*
 * ============================================================
 * RISC-V SoC Linker Script
 * ============================================================
 *
 * Memory map:
 *
 *   RAM: 0x00000000 - 0x0000FFFF
 *        Size = 64 KB
 *
 * Firmware layout:
 *
 *   .text  -> program instructions
 *   .rodata -> constant data
 *   .data  -> initialized variables
 *   .bss   -> zero-initialized variables
 *
 * Stack:
 *   Starts at the top of RAM and grows downward.
 * ============================================================
 */

ENTRY(_start)

/*
 * ------------------------------------------------------------
 * Memory regions
 * ------------------------------------------------------------
 */

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

/*
 * ------------------------------------------------------------
 * Sections
 * ------------------------------------------------------------
 */

SECTIONS
{
    /*
     * Program instructions.
     */
    .text :
    {
        . = ALIGN(4);

        KEEP(*(.text.init))
        *(.text)
        *(.text.*)

        . = ALIGN(4);
    } > RAM

    /*
     * Read-only constants.
     */
    .rodata :
    {
        . = ALIGN(4);

        *(.rodata)
        *(.rodata.*)

        . = ALIGN(4);
    } > RAM

    /*
     * Initialized global/static variables.
     */
    .data :
    {
        . = ALIGN(4);

        *(.data)
        *(.data.*)

        . = ALIGN(4);
    } > RAM

    /*
     * Zero-initialized global/static variables.
     */
    .bss :
    {
        . = ALIGN(4);

        __bss_start = .;

        *(.bss)
        *(.bss.*)
        *(COMMON)

        . = ALIGN(4);

        __bss_end = .;
    } > RAM

    /*
     * --------------------------------------------------------
     * Stack
     * --------------------------------------------------------
     *
     * RAM ends at:
     *
     *     0x00000000 + 64 KB = 0x00010000
     *
     * Stack grows downward from this address.
     */
    . = ALIGN(16);

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /*
     * Symbols available to startup code/debugging.
     */
    PROVIDE(_stack_top = __stack_top);

    /*
     * Make sure the firmware does not exceed RAM.
     */
    ASSERT(. <= ORIGIN(RAM) + LENGTH(RAM),
           "ERROR: Firmware does not fit in RAM")
}
