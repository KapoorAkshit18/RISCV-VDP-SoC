.section .text
.globl _start

_start:
    la sp, stack_top
    call main

1:
    j 1b

.section .bss
.align 4

stack:
    .space 256

stack_top:
