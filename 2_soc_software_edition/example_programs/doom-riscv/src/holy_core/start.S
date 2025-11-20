// BRH 11/12 : startup file for HOLY CORE port

    .section .text.start
    .global _start
_start:
    // Set stack pointer
    la sp, __stacktop

    // holy core exception handler
    la t0, trap_handler
    csrw mtvec, t0

    // zero out the .bss section in the start code
    // because GDB won't load .bss (which is all zeroes)
    call init_bss

    // holy core port :
    // Setup instruction cache : make the RAM cachable
    li t0, 0x00000000
    li t1, 0x7FFFFFFF
    csrrw x0, 0x7C3, t0   # All but RAM base
    csrrw x0, 0x7C4, t1   # All but RAM limit

    // call main
    call main

init_bss:
    la t0, _sbss
    la t1, _ebss
    li t2, 0
bss_loop:
    bgeu t0, t1, bss_done
    sw t2, 0(t0)
    addi t0, t0, 4
    j bss_loop
bss_done:
    ret

.global	_exit
_exit:
    j _exit