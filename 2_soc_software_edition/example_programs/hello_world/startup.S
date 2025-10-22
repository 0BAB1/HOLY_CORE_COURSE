.section .text
.global _start

_start:
    la t0, startup_code
    csrw mepc, t0
    mret

startup_code:
    la sp, _stack_top     // Set stack pointer

    # Setup uncached MMIO region from 0x2000 to 0x3800
    lui x6, 0x2           # x6 = 0x2000
    lui x7, 0x3
    ori x7, x7, -1        # x7 = 0x3800
    csrrw x0, 0x7C1, x6   # MMIO base
    csrrw x0, 0x7C2, x7   # MMIO limit

    call main             // Call main
    j .                   // Infinite loop if main returns