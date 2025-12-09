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

    // cache setup
    li t0, 0x00000000
    li t1, 0x80000000
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1
    csrrw x0, mscratch, t1

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
    li t0, 0x1 
    //csrrw x0, 0x7c0, t0
    ret

.global	_exit
_exit:
    j _exit