/* ============================================================================
 * RISCV-VDP-SoC PHASE-5 LINKER SCRIPT
 * ========================================================================== */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

_stack_top = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
    } > RAM

    .data :
    {
        . = ALIGN(4);
        *(.data*)
        . = ALIGN(4);
    } > RAM

    .sdata :
    {
        . = ALIGN(4);
        *(.sdata*)
        . = ALIGN(4);
    } > RAM

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    __heap_start = .;
    __heap_end = _stack_top;

    PROVIDE(__global_pointer$ = __heap_start + 0x800);

    /DISCARD/ :
    {
        *(.comment*)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}