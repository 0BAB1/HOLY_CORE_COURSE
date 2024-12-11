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
    lui x6, 0x2                 # Load GPIO base address
    addi x19, x0, 0x0           # Set offset to 0
    addi x20, x0, 0x80          # Set offset limit to 128 (i.e., cache size) 
    addi x18, x0, 0
    j loop

loop:
    # reset offsets
    addi x6, x0, 0
    lui x6, 0x2                 # Load GPIO base address 
    addi x19, x0, 0x0           # Set offset to 0 

    addi x18, x18, 0x1
    j sub_loop

sub_loop:
    sw x18, 0(x6)
    addi x6, x6, 0x4            
    addi x19, x19, 0x1         
    bne x19, x20, sub_loop         

    lw x23, 0(x0)               # Done! Create a cache miss to write back.

    # Delay loop: Wait for ~50,000,000 clock cycles
    li x21, 50000000      # Load 50,000,000 into x21
    
delay_loop:
    addi x21, x21, -1           # Decrement x21
    bnez x21, delay_loop        # If x21 != 0, continue looping

    j loop                      # Restart the loop
