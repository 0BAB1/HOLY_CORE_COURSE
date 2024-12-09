# This prgrams fills the cache lines with 0x00000001 from address @0x2000 (GPIO Base addr)
# And then performs a write back through a cache miss.
# Now THAT's some McGyver shit !
# Expected behavior : turn LED on

    .section .text
    .globl _start

_start:
    # Initialization
    lui x6, 0x2                 # Load GPIO base address                        # 00002337
    addi x19, x0, 0x0           # Set offset to 0                               # 00000993
    addi x18, x0, 0x1           # Set data to be written to 1                   # 00100913
    addi x20, x0, 0x80          # Set offest limit to 128 (ie cache size)       # 07f00a13

    # Main loop
    sw x18, 0(x6)               # Store data in offested memory                 # 01232023
    addi x6, x6, 0x4            # Increment memory address                      # 00430313
    addi x19, x19, 0x1          # Keep track of offset : offset++               # 00198993
    bne x19, x20, -0xC          # if offset != 128, restart loop                # FF499AE3

    lw x18, 0(x0)               # Done ! create a cache miss to write back.     # 00002903 

    # Exit strategy : Infinite loop
    addi x0, x0, 0x0            # NOP                                           # 00000013
    beq x0, x0, -0x4            # Repeat                                        # FE000EE3
    