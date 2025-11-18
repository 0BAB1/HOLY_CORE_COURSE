.extern trap_handler
.section .text
.global _start

_start:
    la t0, startup_code
    csrw mepc, t0
    mret

startup_code:
    la sp, _stack_top     // Set stack pointer
    # Setup uncached MMIO region from 0x2000 to 0x3800
    # lui x6, 0x2           # x6 = 0x2000
    # lui x7, 0x3
    # ori x7, x7, -1        # x7 = 0x3800
    # csrrw x0, 0x7C1, x6   # MMIO base
    # csrrw x0, 0x7C2, x7   # MMIO limit

    # Enable traps in PLIC
    li t1, 0x80000000 # plic addr
    li t0, 0xFFFFFFFF # enable all
    sw t0, 0(t1)
    # Setup trap handler address & enable interrupts
    la t0, trap_handler
    csrw mtvec, t0

    li t0, (1 << 3)      // Set Global MIE bit
    csrs mstatus, t0

    // Enable specific interrupts (example: external interrupt)
    li t0, (1 << 11) // MEIE
    csrw mie, t0

    call main
    j .
