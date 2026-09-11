.section .text.init
.globl _start
.type _start, @function

_start:
    /* Stack at 0x00010000, top of 64 KiB RAM */
    la sp, __stack_top

    /* Clear .bss */
    la t0, __bss_start
    la t1, __bss_end

.Lclear_bss:
    beq t0, t1, .Lbss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    jal zero, .Lclear_bss

.Lbss_done:
    jal ra, main

.Lhalt:
    jal zero, .Lhalt

.size _start, .-_start