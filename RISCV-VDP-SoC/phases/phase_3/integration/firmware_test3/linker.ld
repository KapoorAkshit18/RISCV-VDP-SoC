OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text.init :
    {
        KEEP(*(.text.init))
    } > RAM

    .text :
    {
        *(.text)
        *(.text.*)
    } > RAM

    .rodata :
    {
        *(.rodata)
        *(.rodata.*)
    } > RAM

    .data :
    {
        . = ALIGN(4);
        *(.data)
        *(.data.*)
    } > RAM

    .sdata :
    {
        . = ALIGN(4);
        *(.sdata)
        *(.sdata.*)
    } > RAM

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

    . = ALIGN(16);

    __heap_start = .;
    __stack_top  = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}