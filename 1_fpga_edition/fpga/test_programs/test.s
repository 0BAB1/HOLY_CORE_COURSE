# Blink leds
#
# Assembly to blink LEDs once / second in a counter motion.
# Uses a cache miss to write back.
#
# BRH 11/12

.section .text
.align 2
.global _start

start:
    # Initialization
    lui x6, 0x2                 # 00002337 Load GPIO base address x6 <= 0x00002000
    lui x7, 0x2                 # same for x7 <= 0x00002000
    ori x7, x7, -1              # FFF3E393 set GPIO address limit x7 <= 0x00002FFF
    csrrw x0, 0x7C1, x6         # set base in csr
    csrrw x0, 0x7C2, x7         # set limit in csr
    addi x18, x0, 0             # 00000913 main counter, set to 0
    j loop                      # 0040006f

loop:
    addi x18, x18, 0x1          # 00190913 increment counter
    sw x18, 0(x6)               # 01232023 write new counter value to GPIO based address

    # Delay loop: Wait for 50,000,000 clock cycles = 1s @ 50Mhz
    li x21, 50000000            # 02fafab7 / 080a8a93 Load 50,000,000 into x21
    
delay_loop:
    addi x21, x21, -1           # fffa8a93 Decrement x21
    bnez x21, delay_loop        # fe0a9ee3 If x21 != 0, continue looping

    j loop                      # fd9ff06f Restart the loop
