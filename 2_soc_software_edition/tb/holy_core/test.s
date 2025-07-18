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
    # DATA ADDR STORE
    lui x3, 0x1

    # LW TEST START
    lw x18, 8(x3)

    # SW TEST START
    sw x18, 12(x3)

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

    # SB TEST START
    nop
    sb x8, 6(x3)

    # SH TEST START
    sh x8, 1(x0)
    sh x8, 3(x0)
    sh x8, 6(x3)

    # LB TEST START
    addi x7, x3, 0x10
    lw x18, -1(x7)
    lb x18, -1(x7)

    # LBU TEST START
    lbu x19, -3(x7)

    # LH TEST START
    lh x20, -3(x7)
    lh x20, -6(x7)

    # LHU TEST START
    lhu x21, -3(x7)
    lhu x21, -6(x7)

    # CACHE WB TEST
    addi x7, x3, 0x200
    lw x20, 0(x7)

    # CSR FLUSH TEST
    addi x20, x0, 1
    csrrw x21, 0x7C0, x20

    # CSR $ RANGE TEST
    addi x20, x0, 0
    lui x20, 0x2
    addi x21, x20, 0x200
    csrrw x0, 0x7C1, x20
    csrrw x0, 0x7C2, x21

    addi x20, x20, 4
    lui x22, 0xABCD1
    addi x22, x22, 0x111
    sw x22, 0(x20)
    lw x22, 4(x20)
    lw x22, 0(x20)

    # SW INTR TEST
    lui x4, 0x3             # Clint base addr
    la x6, trap             # Trap handler base addr
    csrrw x0, 0x305, x6     # we set mtvec to the trap handler's addr
    addi x5, x0, 1      
    sw x5, 0(x4)            # write 1 to clint's msip
    
    nop

trap:
    csrrs x30, 0x342, x0    # store mcause in x30

soft_irq_check:             # soft intr handler
    li x31, 0x80000003      
    bne x30, x31, timer_irq_check 
    # clear the soft interrupt
    sw x0, 0(x4)
    # skip intr write on return
    csrrs x31, 0x341, x0
    addi x31, x31, 0x4
    csrrw x0, 0x341, x31

timer_irq_check:            # timer irq handler

    j m_ret

m_ret:
    mret # return to where we left the program
