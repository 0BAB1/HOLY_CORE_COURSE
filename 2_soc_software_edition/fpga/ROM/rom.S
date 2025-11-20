    .global _start

_start:
    # ==============================================
    # for TestBench : Jump to Main program directly
    # ==============================================

    la t0, 0x80000000
    jalr x0, t0, 0                

    # ==============================================
    # for FPGA : Infinite leds (debug mode is used to
    # load and execute real program).
    # ==============================================
    
#     lui t0, 0x10010      # t0 = 0x10010000 (LED MMIO base)
#     li t1, 1             # t1 = 1 (LED on)
#     li t2, 0             # t2 = 0 (LED off)
    
# loop:
#     sw t1, 0(t0)         # write LED on
    
#     li t3, 250000        
# l1: 
#     addi t3, t3, -1
#     bnez t3, l1

#     sw t2, 0(t0)         # write LED off
    
#     li t3, 250000        
# l2: 
#     addi t3, t3, -1
#     bnez t3, l2


#     j loop               # repeat forever