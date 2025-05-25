# Blink leds
#
# Assembly to blink LEDs once / second in a counter motion.
# Uses a cache miss to write back.
#
# BRH 11/12

.section .text
.align 2
.global _start

00002337
00000913
0040006f
00000313
00002337
00190913
0040006f
01232023
7c00d073
02fafab7
080a8a93
fffa8a93
fe0a9ee3
fd9ff06f

start:
    # Initialization
    lui x6, 0x2                 # 00002337 Load GPIO base address x6 <= 0x00002000
    addi x18, x0, 0             # 00000913 main counter, set to 0
    j loop                      # 0040006f

loop:
    addi x6, x0, 0              # 00000313 reset x6 GPIO address
    lui x6, 0x2                 # 00002337 Load GPIO base address

    addi x18, x18, 0x1          # 00190913 increment counter
    j sub_loop                  # 0040006f jump @ pc + 0x4

sub_loop:
    sw x18, 0(x6)               # 01232023 write new counter value to GPIO based address

    csrrwi x0, 0x7C0, 0x1       # 7c00d073 Create a cache miss to write back to MMIO

    # Delay loop: Wait for 50,000,000 clock cycles = 1s @ 50Mhz
    li x21, 50000000            # 02fafab7 / 080a8a93 Load 50,000,000 into x21
    
delay_loop:
    addi x21, x21, -1           # fffa8a93 Decrement x21
    bnez x21, delay_loop        # fe0a9ee3 If x21 != 0, continue looping

    j loop                      # fd9ff06f Restart the loop
