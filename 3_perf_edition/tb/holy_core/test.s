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
    lui x3, 0x100

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
    # bug fix 12/2025
    li t0, 0x0c6
    bgez t0, bge_test_2 # should branch !
    j dummy_destination # if not, flow is broken here
    bge_test_2:
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
    # dummy lw to await potential cache flush delays
    lw x0, 0(x3)

    # SH TEST START
    nop
    nop
    sh x8, 6(x3)
    # cause a cache flush...
    addi x7, x0, 0x1
    csrrw x0, 0x7C0, x7
    # dummy lw to await potential cache flush delays
    lw x0, 0(x3)

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

    # MUL TEST START
    li x5, 0x12345678
    li x6, 0x1212ABCD
    mul x4, x5, x6

    # MULH TEST START
    li x5, 0x00000005
    li x6, 0xFFFFFFFF
    mulh x4, x5, x6

    # MULHSU TEST START
    li x5, 0xFFFFFFFF
    li x6, 0xF123F123
    mulhsu x4, x5, x6

    # MULHU TEST START
    mulhu x4, x5, x6

    # DIV TEST START
    li x5, 0xF0000000
    li x6, 0x00000003
    div x4, x5, x6

    # DIVU TEST START
    li x5, 0xF0000000
    li x6, 0x00000003
    divu x4, x5, x6

    # REM TEST START
    li x5, 0xF0000005
    li x6, 0x00000003
    rem x4, x5, x6

    # REMU TEST START
    remu x4, x5, x6

    #######################
    # PRIV SPECS TESTS
    #######################

    # Set no cache for now
    li t0, 0x00000000
    li t1, 0xFFFFFFFF
    csrrw x0, 0x7C1, t0
    csrrw x0, 0x7C2, t1
    csrrw x0, 0x7C3, t0
    csrrw x0, 0x7C4, t1

    ################
    # SW INTR TEST
    ################
    lui x4, 0x40000         # Clint base addr
    la x6, trap             # Trap handler base addr
    csrrw x0, mtvec, x6     # we set mtvec to the trap handler's addr
    
    # we configure CSRs to enable interrupts
    li t0, (1 << 11) | (1 << 7) | (1 << 3)
    csrw mie, t0
    li t0, (1 << 3)
    csrw mstatus, t0

    addi x5, x0, 1      
    sw x5, 0(x4)            # write 1 to clint's msip
    # dummy lw to await potential cache flush delays
    lw x0, 0(x3)
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
    li x4, 0x90000000       # plic base addr
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


#######################
# DEBUG SPECS TESTS
#######################

wait_for_debug_mode:
    # load addrs so TB can grab it and set CORE's
    # debug jumps addresses constants
    la t0, debug_rom 
    la t1, debug_exception
    nop
    # tb will send a debug request, effectively jumping
    # to our own "debug ROM" for total control over the test
    # -> debug rom which is defined below in this file
    li t3, 0x2
    csrr t2, dscratch0
    beq t2, t3, cache_stress_test
    j wait_for_debug_mode

set_i_cache:
    # BUG FIX 12/2025
    # the lowwing is where single step executes an instruction
    # changing the instr cache cachable range should provoke a bug
    csrrw x0, 0x7c3, t0
    nop

###########################################################################
###########################################################################
###################### TEST FUNCTIONS & HANDLERS ##########################
###########################################################################
###########################################################################

# some dummy code
dummy_destination:
    nop
    j .

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
    # simple jump to emulate real entry
    j debug_rom_entry
    nop
debug_rom_entry:
    # in real debug rom, there is a fence at entry
    fence
    # if dscratch0 == 1 (we already did first d_ret test)
    # we want to skip to the single step debug test
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
    # and d_ret. the cpu should come back
    # right after. Except if single step already was 1
    # in which case we clear it, write 2 to scratch for
    # the testbench to check and  leave
    csrr    t0, dcsr
    # Check if we already did single step test before ?
    andi    t1, t0, (1 << 2) # t1 = dcsr.step ? 4 : 0 (check if flag is set)
    beqz    t1, set_step     # if step == 0, go set it, if not, advance to clear_step.
    # if we arrive here, we did the single step once
    # so we restore dpc frrm set_i_cache to old one
    # (stored in dscratch1) and advance to clear the step
    csrr    t0, dscratch1
    csrw    dpc, t0
clear_step:
    # once dpc is restore, we clear step, hint we did it in dscratch0 and dret back to the test
    csrci   dcsr, 4
    li      t2, 2
    csrw    dscratch0, t2
    # set scratch0 to 2 to flag this tst as done
    csrwi   dscratch0, 0x2
    dret
set_step:
    # set single step flag
    csrsi   dcsr, 4
    # BUG FIX 12/2025
    # Single stepping and I$ setting causes huge timing issues
    # so here, we'll set dpc to a piece of code that especially re-activate the
    # I$.
    # we save that address in dscratch1 to restore it later
    csrrw   t1, dpc, x0
    csrrw   x0, dscratch1, t1
    #set dpc to problematic instruction
    la      t0, set_i_cache
    csrrw   x0, dpc, t0
    nop
    # t0 will be used to set upper limit of instr_non_cachable_limit, which we set to debug ROM start
    la t0, debug_rom
    # addi t0, t0, -4
    dret

# ========================================
# DATA STRESS TEST - Phase 1: Sequential Writes
# ========================================
# Memory region: 0x1000 - 0x1040 (16 words)
# Pattern: each word = its own address
# Checksum: XOR of all written values

cache_stress_test:
    # Setup
    lui x3, 0x1              # x3 = 0x1000 (base address)
    addi x4, x3, 0x40        # x4 = 0x1040 (end = 16 words)
    li x10, 0                # x10 = checksum
    li x7, 0xA5A5A500        # x7 = base pattern
    csrwi 0x7c1, 0x0         # cache setup
    csrwi 0x7c2, 0x0         # cache setup
    csrwi 0x7c3, 0x0         # cache setup
    csrwi 0x7c4, 0x0         # cache setup

write_loop:
    or x8, x7, x3            # x8 = 0xA5A5A500 | addr (unique per word)
    sw x8, 0(x3)             # mem[addr] = pattern
    add x10, x10, x8         # checksum += pattern
    addi x3, x3, 4
    bne x3, x4, write_loop

    # Now verify by reading back
    lui x3, 0x1              # reset to 0x1000
    li x11, 0                # x11 = read checksum

read_loop:
    lw x5, 0(x3)             # x5 = mem[addr]
    add x11, x11, x5         # read_checksum += value
    addi x3, x3, 4
    bne x3, x4, read_loop

    # Store results at 0x1200
    li x6, 0x1200
    sw x10, 0(x6)            # store write checksum
    sw x11, 4(x6)            # store read checksum

    # Flush the cache (also a marker to tell this phase is over# so we can run asserions)
    csrwi 0x7C0, 0x1

# ========================================
# CACHE STRESS TEST - Phase 2: Read-Write Interleaving
# ========================================
# Write to region A, read from A, write to region B
# Stresses cache with rapid R/W switching

    # ---- Phase 1: Fill region A (0x1000-0x103F) ----
    lui x3, 0x1              # x3 = 0x1000
    addi x4, x3, 0x40        # x4 = 0x1040 (16 words)
    li x9, 1                 # counter

fill_a:
    sw x9, 0(x3)
    addi x9, x9, 1
    addi x3, x3, 4
    bne x3, x4, fill_a

    # ---- Phase 2: Read A, write to B (0x1100-0x113F) ----
    lui x3, 0x1              # x3 = 0x1000 (read from A)
    li x4, 0x1100            # x4 = 0x1100 (write to B)
    li x5, 0x1140            # x5 = end of B
    li x10, 0                # checksum

interleave_loop:
    lw x6, 0(x3)             # read from A
    add x10, x10, x6         # checksum += value
    sw x6, 0(x4)             # write same value to B
    addi x3, x3, 4
    addi x4, x4, 4
    bne x4, x5, interleave_loop

    # ---- Phase 3: Verify B matches A ----
    lui x3, 0x1              # x3 = 0x1000 (A)
    li x4, 0x1100            # x4 = 0x1100 (B)
    li x5, 0x1140            # end
    li x11, 0                # verify checksum

verify_loop:
    lw x6, 0(x3)             # read A
    lw x7, 0(x4)             # read B
    add x11, x11, x7         # checksum from B
    addi x3, x3, 4
    addi x4, x4, 4
    bne x4, x5, verify_loop

    # Store results at 0x1200
    li x6, 0x1200
    sw x10, 0(x6)            # checksum from interleave
    sw x11, 4(x6)            # checksum from verify

    # Flush the cache (also a marker to tell this phase is over# so we can run asserions)
    csrwi 0x7C0, 0x1

# ========================================
# CACHE STRESS TEST - Phase 3: Jumps + Large Memory
# ========================================
# - Jumps across code to stress I$ 
# - Writes across 4 separate memory regions
# - 64 words per region = 256 words total

    li x10, 0                # checksum
    li x9, 1                 # counter
    
    # Region bases
    lui x20, 0x1             # x20 = 0x1000 (region A)
    li x21, 0x1200           # x21 = 0x1200 (region B)
    li x22, 0x1400           # x22 = 0x1400 (region C)
    li x23, 0x1600           # x23 = 0x1600 (region D)
    
    j phase3_start

# ============ NOP BLOCK 1 ============
.balign 64
nop_block_1:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j write_region_b

# ============ NOP BLOCK 2 ============
.balign 64
nop_block_2:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j write_region_d

# ============ NOP BLOCK 3 ============
.balign 64
nop_block_3:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j verify_start

# ============ MAIN CODE ============
.balign 64
phase3_start:
    # ---- Write Region A: 0x1000-0x10FF (64 words) ----
    mv x3, x20
    addi x4, x3, 0x100       # end = 0x1100
write_region_a:
    sw x9, 0(x3)
    add x10, x10, x9
    addi x9, x9, 1
    addi x3, x3, 4
    bne x3, x4, write_region_a
    j nop_block_1            # jump far

# ============ NOP BLOCK 4 ============
.balign 64
nop_block_4:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j write_region_c

.balign 64
write_region_b:
    # ---- Write Region B: 0x1200-0x12FF (64 words) ----
    mv x3, x21
    addi x4, x3, 0x100
write_region_b_loop:
    sw x9, 0(x3)
    add x10, x10, x9
    addi x9, x9, 1
    addi x3, x3, 4
    bne x3, x4, write_region_b_loop
    j nop_block_4            # jump far

.balign 64
write_region_c:
    # ---- Write Region C: 0x1400-0x14FF (64 words) ----
    mv x3, x22
    addi x4, x3, 0x100
write_region_c_loop:
    sw x9, 0(x3)
    add x10, x10, x9
    addi x9, x9, 1
    addi x3, x3, 4
    bne x3, x4, write_region_c_loop
    j nop_block_2            # jump far

.balign 64
write_region_d:
    # ---- Write Region D: 0x1600-0x16FF (64 words) ----
    mv x3, x23
    addi x4, x3, 0x100
write_region_d_loop:
    sw x9, 0(x3)
    add x10, x10, x9
    addi x9, x9, 1
    addi x3, x3, 4
    bne x3, x4, write_region_d_loop
    j nop_block_3            # jump far

# ============ VERIFY ALL REGIONS ============
.balign 64
verify_start:
    li x11, 0                # verify checksum
    
    # Verify A
    mv x3, x20
    addi x4, x3, 0x100
verify_a:
    lw x5, 0(x3)
    add x11, x11, x5
    addi x3, x3, 4
    bne x3, x4, verify_a
    
    # Verify B
    mv x3, x21
    addi x4, x3, 0x100
verify_b:
    lw x5, 0(x3)
    add x11, x11, x5
    addi x3, x3, 4
    bne x3, x4, verify_b
    
    # Verify C
    mv x3, x22
    addi x4, x3, 0x100
verify_c:
    lw x5, 0(x3)
    add x11, x11, x5
    addi x3, x3, 4
    bne x3, x4, verify_c
    
    # Verify D
    mv x3, x23
    addi x4, x3, 0x100
verify_d:
    lw x5, 0(x3)
    add x11, x11, x5
    addi x3, x3, 4
    bne x3, x4, verify_d

    # Store results at 0x1800
    li x6, 0x1800
    sw x10, 0(x6)            # write checksum
    sw x11, 4(x6)            # verify checksum

    # Flush the cache (also a marker to tell this phase is over# so we can run asserions)
    csrwi 0x7C0, 0x1