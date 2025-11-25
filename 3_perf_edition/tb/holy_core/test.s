# HOLY_CORE BASIC TEST PROGRAM
#
# This program tests basic behavior of the core.
# This test does not ensure compliance but rather
# serve as a quick reference to know if
# the design compiles and if a change
# broke the basic CPU behavior.
#
# BRH 7/25

.section .text
.global _start

_start:
    # By default, tests are done with cache, both on I$ and D$
    # COMMENT OUT the following and modify  synth params in test
    # harness if you wanna test with no cache.
    li t0, 0xFFFFFFFF
    li t1, 0xFFFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    # DATA ADDR STORE
    lui x3, 0x1

    # LW TEST START
    lw x18, 8(x3)

    # SW TEST START
    sw x18, 12(x3)
    # + provke cache fluch in case of
    # data caching
    addi x19, x0, 0x1
    csrrw x0, 0x7C0, x19

    # ADD TEST START
    lw x19, 16(x3)
    add x20, x18, x19

    # AND TEST START
    and x21, x18, x20
    lw x5, 20(x3)
    lw x6, 24(x3)
    or x7, x5, x6

    # BEQ TEST START
    beq x6, x7, _start # should not branch
    lw x22, 8(x3)
    beq x18, x22, beq_lw
    nop
    nop
    beq_to_end:
    beq x0, x0, beq_end
    beq_lw:
    lw x22, 0(x3)
    beq x22, x22, beq_to_end
    beq_end:
    nop

    # JAL TEST START
    jal x1, jal_lw
    nop
    nop
    nop
    nop
    jal_lw:
    lw x7, 12(x3)

    # ADDI TEST START
    addi x26, x7, 0x1AB
    nop

    # AUIPC TEST START
    auipc x5, 0x1F1FA
    lui x5, 0x2F2FA

    # SLTI TEST START
    nop
    slti x23, x23, 1

    # SLTIU TEST START
    nop
    sltiu x22, x19, 1

    # XORI TEST START
    nop
    xori x19, x18, 0

    # ORI TEST START
    nop
    ori x21, x20, 0

    # ANDI TEST START
    andi x18, x20, 0x7FF
    nop
    andi x20, x21, 0

    # SLLI TEST START
    slli x19, x19, 4
    nop

    # SRLI TEST START
    srli x20, x19, 4
    nop

    # SRAI TEST START
    srai x21, x21, 4
    nop

    # SUB TEST START
    sub x18, x21, x18

    # SLL TEST START
    addi x7, x0, 8
    sll x18, x18, x7

    # SLT TEST START
    slt x17, x22, x23

    # SLTU TEST START
    sltu x17, x22, x23

    # XOR TEST START
    xor x17, x18, x19

    # SRL TEST START
    srl x8, x19, x7

    # SRA TEST START
    sra x8, x19, x7

    # BLT TEST START
    blt x17, x8, blt_addi # not taken
    blt x8, x17, bne_test # taken
    blt_addi:
    addi x8, x0, 12 # never exec !

    # BNE TEST START
    bne_test:
    bne x8, x8, bne_addi # not taken
    bne x8, x17, bge_test # taken
    bne_addi:
    addi x8, x0, 12

    # BGE TEST START
    bge_test:
    bge x8, x17, bge_addi # not taken
    bge x8, x8, bltu_test # taken
    bge_addi:
    addi x8, x0, 12

    # BLTU TEST START
    bltu_test:
    bltu x8, x17, bltu_addi # not taken
    bltu x17, x8, bgeu_test # taken
    bltu_addi:
    addi x8, x0, 12

    # BGEU TEST START
    bgeu_test:
    bgeu x17, x8, bgeu_addi # not taken
    bgeu x8, x17, jalr_test # taken
    bgeu_addi:
    addi x8, x0, 12

    # JALR TEST START
    jalr_test:
    auipc x7, 0
    addi x7, x7, 20
    jalr x1, -4(x7)
    addi x8, x0, 12
    nop

    # SB TEST START
    sb x8, 6(x3)
    # cause a cache flush so the tb can read store result in mem
    addi x7, x0, 0x1
    csrrw x0, 0x7C0, x7

    # SH TEST START
    nop
    nop
    sh x8, 6(x3)
    # cause a cache flush...
    addi x7, x0, 0x1
    csrrw x0, 0x7C0, x7

    # LB TEST START
    addi x7, x3, 0x10
    nop
    lb x18, -1(x7)

    # LBU TEST START
    lbu x19, -3(x7)

    # LH TEST START
    nop
    lh x20, -6(x7)

    # LHU TEST START
    nop
    lhu x21, -6(x7)

    ###############################################################################
    # due to increased cache complexity, the cache testbench is now
    # better and more "systemic", meaning these tests are both now
    # prone to False Negatives and are not worth maintaining...
    # Furthermore, cocotb's tests suite and fpga's SoC simulation are more
    # likely to shed light on specific problems that would not be catched
    # here anyway.
    ###############################################################################

    # # CACHE WB TEST
    # addi x7, x3, 0x200
    # lw x20, 0(x7)

    # # CSR FLUSH TEST
    # addi x20, x0, 1
    # csrrw x21, 0x7C0, x20

    # # CSR $ RANGE TEST
    # addi x20, x0, 0
    # lui x20, 0x2
    # addi x21, x20, 0x200
    # csrrw x0, 0x7C1, x20
    # csrrw x0, 0x7C2, x21

    # addi x20, x20, 4
    # lui x22, 0xABCD1
    # addi x22, x22, 0x111
    # sw x22, 0(x20)
    # lw x22, 4(x20)
    # lw x22, 0(x20)

    # to easy testbench, we set all as non cachable
    # for the priv specs specs
    li t0, 0x00000000
    li t1, 0xFFFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    ################
    # SW INTR TEST
    ################
    lui x4, 0x3             # Clint base addr
    la x6, trap             # Trap handler base addr
    csrrw x0, mtvec, x6     # we set mtvec to the trap handler's addr
    
    # we configure CSRs to enable interrupts
    li t0, (1 << 11) | (1 << 7) | (1 << 3)
    csrw mie, t0
    li t0, (1 << 3)
    csrw mstatus, t0

    addi x5, x0, 1      
    sw x5, 0(x4)            # write 1 to clint's msip
    # return should happen here

    ################
    # TIMER INTR TEST
    ################
    lui x7, 0x4
    add x5, x4, x7          # build Clint's mtimecmp base addr
    lui x7, 0xC             
    add x7, x4, x7          # build Clint's mtime "near" base addr
    sw x0, 4(x5)            # set high word of mtimecmp to 0
    lw x8, -8(x7)           # get the current mtime value
    addi x8, x8, 0x10       # add 16 to the timer and store it back to timer cmp
    sw x8, 0(x5)
    # loop until timer intr happens
wait_for_timer_irq:
    j wait_for_timer_irq
    # handler returns on this NOP
    nop

    ################
    # EXTERNAL INTR TEST
    ################
    # set up plic by enabling intr
    li x4, 0x0000F000       # plic base addr
    ori x5, x0, 0x1         
    sw x5, 0(x4)            # enable ext intr #1
    nop                     # signal tb we are about to wait for ext intr

wait_for_ext_irq:
    j wait_for_ext_irq
    # handler returns on this NOP
    nop

    ################
    # ECALL EXCEPTION TEST
    ################

    nop
    ecall                   # provoke ecall

    ################
    # DEBUG MODE TEST
    ################

wait_for_debug_mode:
    la t0, debug_rom # load addrs for compiler issues
    la t1, debug_exception # load addrs for compiler issues
    nop
    # tb will send a debug request, effectively jumping
    # to "debug ROM", which we can find below
    j wait_for_debug_mode

#########################
# Trap handler
#########################

trap:
    csrrs x30, 0x342, x0    # store mcause in x30

soft_irq_check:             # soft intr handler
    li x31, 0x80000003      
    bne x30, x31, timer_irq_check 
    # clear the soft interrupt
    sw x0, 0(x4)
    # mepc += 4
    # to skip intr write on return
    csrrs x31, 0x341, x0
    addi x31, x31, 0x4
    csrrw x0, 0x341, x31
    j m_ret

timer_irq_check:            # timer irq handler
    li x31, 0x80000007
    bne x30, x31, ext_irq_check 
    # clear tht imer intr by pumping the mtimecmp to full F
    li x9, 0xFFFFFFFF
    sw x9, 0(x5)            # x5 should already contain mtimecmp base addr
    # mepc += 4
    # to skip intr write on return
    csrrs x31, 0x341, x0
    addi x31, x31, 0x4
    csrrw x0, 0x341, x31
    j m_ret

ext_irq_check:
    li x31, 0x8000000B
    bne x30, x31, ecall_check
    # claim the interrupt
    lw x8, 4(x4)

    # Do a loop as place holder
    li t0, 32
    loop:
    addi t0, t0, -1
    bnez t0, loop

    # clear the intr using NOP which 
    # the tb will use as a placeholder
    # to clear the ext intr
    nop
    # signal completion to the plic
    sw x8, 4(x4)
    # mepc += 4
    # to skip intr write on return
    csrrs x31, 0x341, x0
    addi x31, x31, 0x4
    csrrw x0, 0x341, x31
    j m_ret

ecall_check:
    li x31, 0x0000000B
    bne x30, x31, m_ret
    # Do a loop as placeholder
    li t0, 32 
    loop2:
    addi t0, t0, -1
    bnez t0, loop2
    # mepc += 4
    # to skip intr write on return
    csrrs x31, 0x341, x0
    addi x31, x31, 0x4
    csrrw x0, 0x341, x31
    j m_ret


m_ret: # return form trap routine
    mret # return to where we left the program

#########################
# Debug ROM
#########################

debug_rom:
    # some nops and a dret
    nop
    # if dscratch0 == 1, we want to do the single
    #step debug test
    csrr t2, dscratch0
    li t3, 0x1
    beq t2, t3, single_step_test
    nop
    nop
    # we first make an ebreak test
    # which should return to the "normal" park loop
    # and then we'll branch to test dret bhavior
    beq x0, x5, d_ret
    addi x5, x0, 0x0
    ebreak
d_ret:
    nop
    nop
    nop
    # right before dret, we set dscratch0 to 1
    # to signal the first debug pass was done
    csrwi dscratch0, 0x1
    dret
    
debug_exception:
    nop
    nop
    nop
    nop
    nop
    j debug_rom

single_step_test:
    nop
    nop
    # we set dscr's step flag to 1
    # and d_ret. the cu should come back
    # right after. Except if single step already was 1
    # in which case we clear it, write 2 to scratch for
    # the testbench to check and  leave
    csrr   t0, 0x7b0        # dcsr
    andi   t1, t0, (1 << 2) # t1 = dcsr.step ? 4 : 0
    beqz   t1, set_step     # if step == 0, go set it
clear_step:
    csrci  0x7b0, 4
    li     t2, 2
    csrw   0x7b2, t2
    dret
set_step:
    csrsi  0x7b0, 4
    dret
