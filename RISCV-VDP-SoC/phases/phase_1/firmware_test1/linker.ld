MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 1024
}

SECTIONS
{
    .text :
    {
        *(.text*)
    } > RAM

    .rodata :
    {
        *(.rodata*)
    } > RAM

    .data :
    {
        *(.data*)
    } > RAM

    .bss :
    {
        *(.bss*)
        *(COMMON)
    } > RAM
}