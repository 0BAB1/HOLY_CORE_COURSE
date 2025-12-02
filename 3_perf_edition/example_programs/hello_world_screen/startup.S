.section .text
.global _start

_start:
    
    la sp, _stack_top     // Set stack pointer

    # Setup uncached MMIO region from 0x2000 to 0x3800
    li t0, 0x00000000
    li t1, 0xFFFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    call main             // Call main
    j .                   // Infinite loop if main returns