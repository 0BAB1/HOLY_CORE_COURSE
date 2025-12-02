.section .text
.global _start

_start:
    la t0, startup_code
    csrw mepc, t0
    mret

startup_code:
    la sp, _stack_top     // Set stack pointer

    # Setup caches
    li t0, 0x00000000
    li t1, 0x7FFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    call main             // Call main
    j .                   // Infinite loop if main returns