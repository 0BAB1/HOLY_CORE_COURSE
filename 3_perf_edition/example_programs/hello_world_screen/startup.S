.section .text
.global _start

_start:
    
    la sp, _stack_top     // Set stack pointer

    # Setup caches
    li t0, 0x00000000
    #li t1, 0x800007f8
    li t1, 0xFFFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    li t1, 0x80000000
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    # Setup trap handler address & enable interrupts
    la t0, trap_handler
    csrw mtvec, t0

    call main             // Call main
    j .                   // Infinite loop if main returns