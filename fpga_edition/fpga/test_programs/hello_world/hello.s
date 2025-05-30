.section .text
.align 1
.global _start

_start:
    # Setup uncached MMIO region from 0x2000 to 0x2FFF
    lui x6, 0x2                 # x6 = 0x2000
    lui x7, 0x2
    ori x7, x7, -1              # x7 = 0x2FFF
    csrrw x0, 0x7C1, x6         # MMIO base
    csrrw x0, 0x7C2, x7         # MMIO limit

    # UARTLite base at 0x2800
    li x10, 0x2800              # x10 = UART base
    la x11, string              # x11 = address of string
    li x12, 14                  # x12 = length of string

loop:
    lb x13, 0(x11)              # load byte from string
wait:
    lw x14, 8(x10)              # read UART status (8h)
    andi x14, x14, 0x8          # test bit n°3 (TX FIFO not full)
    bnez x14, wait              # if not ready, spin
    sb x13, 4(x10)              # write byte to TX register (4h)

    addi x11, x11, 0x1          # next char
    addi x12, x12, -1           # decrement counter
    bnez x12, loop              # loop until done

    # Done
    j .

.section .rodata
.align 1
string:
    .asciz "Hello, World\n\r"
