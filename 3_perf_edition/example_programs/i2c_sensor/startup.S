.section .text
.global _start

_start:
    la sp, _stack_top     // Set stack pointer
    # Setup uncached MMIO region from 0x2000 to 0x3800
    addi x6, x0, 0           
    lui x7, 0xFFFFF
    ori x7, x7, -2048     
    csrrw x0, 0x7C1, x6   # MMIO base
    csrrw x0, 0x7C2, x7   # MMIO limit
    call main             // Call main
    j .                   // Infinite loop if main returns