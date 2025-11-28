    .global _start

_start:
    # ==============================================
    # for TestBench : Jump to Main program directly
    # ==============================================

    # # instr cache setup
    # li t0, 0x0
    # li t0, 0x7FFFFFFF
    # csrrw x0, 0x7C1, t0
    # csrrw x0, 0x7C2, t1

    # # data cache setup
    # li t0, 0x0
    # li t1, 0x7FFFFFFF
    # csrrw x0, 0x7C3, t0
    # csrrw x0, 0x7C4, t1

    # # jump to program in cocotb's ram
    # la t0, 0x80000000
    # jalr x0, t0, 0                

#     # ==============================================
#     # for FPGA : Infinite leds (debug mode is used to
#     # load and execute real program).
#     # ==============================================

    # # instr cache setup
    # li t0, 0x0
    # li t0, 0x7FFFFFFF
    # csrrw x0, 0x7C1, t0
    # csrrw x0, 0x7C2, t1

    # # data cache setup
    # li t0, 0x0
    # li t1, 0x7FFFFFFF
    # csrrw x0, 0x7C3, t0
    # csrrw x0, 0x7C4, t1
    
    lui t0, 0x10010      # t0 = 0x10010000 (LED MMIO base)
    li t1, 1             # t1 = 1 (LED on)
    li t2, 0             # t2 = 0 (LED off)
    
loop:
    sw t1, 0(t0)         # write LED on
    
    li t3, 250000        
l1: 
    addi t3, t3, -1
    bnez t3, l1

    sw t2, 0(t0)         # write LED off
    
    li t3, 250000        
l2: 
    addi t3, t3, -1
    bnez t3, l2


   j loop               # repeat forever