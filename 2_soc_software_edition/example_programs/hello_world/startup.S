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

    # Setup uncached range for instruction cache as well
    li t0, 0x00000000
    li t1, 0x7FFFFFFF
    csrrw x0, 0x7C3, t0   # All but RAM base
    csrrw x0, 0x7C4, t1   # All but RAM limit

    call main             // Call main
    j .                   // Infinite loop if main returns