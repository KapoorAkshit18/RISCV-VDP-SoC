.section .text.start
.global _start
.type _start, @function

_start:
    li sp, 0x00010000

    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    li s0, 0
    call main

1:
    j 1b

.size _start, .-_start
