# HOLY_CORE TESTBECH
#
# Based on a fixed test prgram to test
# The basics (very) quickly. This test
# Does not ensure compliance but rather
# serve as a quick reference to know if
# the design compiles and if a change
# broke the basic CPU behavior. RV
# standards compliance is ensured by
# another tesbench meant to work with
# riscof signature system.
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
import numpy as np

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
AXI_PERIOD = 10
CPU_PERIOD = 10

# CACHE STATES CST
IDLE                        = 0b0000
SENDING_WRITE_REQ           = 0b0001
SENDING_WRITE_DATA          = 0b0010
WAITING_WRITE_RES           = 0b0011
SENDING_READ_REQ            = 0b0100
RECEIVING_READ_DATA         = 0b0101
# LITE states, only for data cache
LITE_SENDING_WRITE_REQ      = 0b0110
LITE_SENDING_WRITE_DATA     = 0b0111
LITE_WAITING_WRITE_RES      = 0b1000
LITE_SENDING_READ_REQ       = 0b1001
LITE_RECEIVING_READ_DATA    = 0b1010

async def NextInstr(dut):
    """Wait for a clock edge, but skip cycles while core is stalled."""
    # Wait until not stalled
    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)
    # Then step one more cycle
    await RisingEdge(dut.clk)

def binary_to_hex(bin_str):
    # Convert binary string to hexadecimal
    hex_str = hex(int(str(bin_str), 2))[2:]
    hex_str = hex_str.zfill(8)
    return hex_str.upper()

def hex_to_bin(hex_str):
    # Convert hex str to bin
    bin_str = bin(int(str(hex_str), 16))[2:]
    bin_str = bin_str.zfill(32)
    return bin_str.upper()

def read_cache(cache_data, line) :
    """To read cache_data, because the packed array makes it an array of bits..."""
    l = 127 - line
    return (int(str(cache_data.value[32*l:(32*l)+31]),2))

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())

@cocotb.coroutine
async def init_memory(axi_ram : AxiRam, hexfile, base_addr):
    addr_offset = 0
    with open(hexfile, "r") as file:
        for raw_instruction in file :
            addr = addr_offset + base_addr
            str_instruction = raw_instruction.split("/")[0].strip()
            instruction = int(str_instruction, 16).to_bytes(4,'little')
            axi_ram.write(addr, instruction)
            axi_ram.hexdump(addr,4)
            addr_offset += 4

@cocotb.test()
async def cpu_insrt_test(dut):

    await inst_clocks(dut)

    # ==============
    # Testbench MEMORY MAP
    # (Not meant to be coherent, just raw testing)
    # ==============
    # 0xFFFF
    # PLIC Module registers
    # 0xF000 
    # ==============
    # 0xEFFF
    # CLINT Module registers
    # 0x3000 
    # ==============
    # 0x2FFF
    # Trap handler code
    # 0x2000
    # ==============
    # 0x1FFF
    # Data
    # 0x1000 (stored in gp : x3)
    # ==============
    # 0x0FFF
    # Instructions
    # 0x0000
    #===============

    SIZE = 2**14

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)

    await cpu_reset(dut)

    print("init axi ram")
    await init_memory(axi_ram_slave, "./test.hex", 0x0000)
    await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)
    print("init axi lite ram")
    await init_memory(axi_lite_ram_slave, "./test.hex", 0x0000)
    await init_memory(axi_lite_ram_slave, "./test_dmemory.hex", 0x1000)


    ##################
    # SAVE BASE ADDR IN X3
    # 000011B7  DATA ADDR STORE | x3  <= 00001000
    ##################
    print("\n\nSAVING DATA BASE ADDR\n\n")

    # Wait a clock cycle for the instruction to execute
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk) # lui x3 0x1
    await Timer(1, units="ns")
    # Check the value of reg x18
    assert binary_to_hex(dut.core.regfile.registers[3].value) == "00001000"

    ##################
    # LOAD WORD TEST 
    # lw x18 0x8(x3)      | x18 <= DEADBEEF
    ##################
    print("\n\nTESTING LW\n\n")

    # The first instruction for the test in imem.hex load the data from
    # dmem @ adress 0x00000008 that happens to be 0xDEADBEEF into register x18

    # Wait for the cache to retrieve data
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)

    assert binary_to_hex(dut.core.instruction.value) == "0081A903"
    await RisingEdge(dut.clk) # lw x18 0x8(x3)
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "DEADBEEF"

    ##################
    # STORE WORD TEST 
    # sw x18 0xC(x3)      | 0xC <= DEADBEEF
    ##################
    print("\n\nTESTING SW\n\n")
    test_address = int(0xC / 4) 

    if dut.core.DCACHE_EN.value:
        # Check the inital state
        # assert binary_to_hex(dut.core.gen_data_cache.data_cache.cache_data[test_address].value) == "F2F2F2F2"
        assert read_cache(dut.core.gen_data_cache.data_cache.cache_data, test_address) == int("F2F2F2F2",16)

        await RisingEdge(dut.clk) # sw x18 0xC(x3)
        assert read_cache(dut.core.gen_data_cache.data_cache.cache_data, test_address) == int("DEADBEEF",16)
    else:
        assert int.from_bytes(axi_lite_ram_slave.read(0x100C, 4), byteorder="little") == 0xF2F2F2F2

        while(dut.core.stall.value == 1) :
            await RisingEdge(dut.clk)   # sw x18 0xC(x3)
            
        assert int.from_bytes(axi_lite_ram_slave.read(0x100C, 4), byteorder="little") == 0xDEADBEEF

    await Timer(1, units="ns")
    ##################
    # ADD TEST
    # lw x19 0x10(x3)     | x19 <= 00000AAA
    # add x20 x18 x19     | x20 <= DEADC999
    ##################
    print("\n\nTESTING ADD\n\n")

    # Expected result of x18 + x19
    expected_result = (0xDEADBEEF + 0x00000AAA) & 0xFFFFFFFF
        
    await NextInstr(dut)  # lw x19 0x10(x3)

    assert binary_to_hex(dut.core.regfile.registers[19].value) == "00000AAA"

    await NextInstr(dut) # add x20 x18 x19
    assert dut.core.regfile.registers[20].value == expected_result

    ##################
    # AND TEST
    # and x21 x18 x20 (result shall be 0xDEAD8889)
    ##################
    print("\n\nTESTING AND\n\n")

    # Use last expected result, as this instr uses last op result register
    expected_result = expected_result & 0xDEADBEEF
    await NextInstr(dut) # and x21 x18 x20
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "DEAD8889"

    ##################
    # OR TEST
    # For this one, I decider to load some more value to change the "0xdead.... theme" ;)
    # lw x5 0x14(x3)      | x5  <= 125F552D
    # lw x6 0x18(x3)      | x6  <= 7F4FD46A
    # or x7 x5 x6         | x7  <= 7F5FD56F
    ##################
    print("\n\nTESTING OR\n\n")
    await Timer(1, units="ns")

    await NextInstr(dut) # lw x5 0x14(x3) | x5  <= 125F552D
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "125F552D"

    await NextInstr(dut) # lw x6 0x18(x3) | x6  <= 7F4FD46A
    assert binary_to_hex(dut.core.regfile.registers[6].value) == "7F4FD46A"

    await NextInstr(dut) # or x7 x5 x6    | x7  <= 7F5FD56F
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "7F5FD56F"

    ##################
    # BEQ TEST
    # beq x6 x7 _start    | #1 SHOULD NOT BRANCH
    # lw x22 0x8(x3)      | x22 <= DEADBEEF
    # beq x18 x22 0x10    | #2 SHOULD BRANCH (+ offset)
    # nop                 | NEVER EXECUTED
    # nop                 | NEVER EXECUTED
    # beq x0 x0 0xC       | #4 SHOULD BRANCH (avoid loop)
    # lw x22 0x0(x3)      | x22 <= AEAEAEAE
    # beq x22 x22 -0x8    | #3 SHOULD BRANCH (-offset)
    # nop                 | FINAL NOP
    ##################
    print("\n\nTESTING BEQ\n\n")
    await NextInstr(dut) # beq x6 x7 NOT TAKEN

    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk) # lw x22 0x8(x3)
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "DEADBEEF"

    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert dut.core.control_unit.branch.value == 1
    await RisingEdge(dut.clk) # beq x18 x22 TAKEN

    await NextInstr(dut) # lw x22 0x0(x3)
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "AEAEAEAE"

    await NextInstr(dut) # beq x22 x22 -0x8 TAKEN

    await NextInstr(dut) # beq x0 x0 0xC TAKEN
    await NextInstr(dut) # NOP

    ##################
    # jal x1 (to lw instruction below)
    # nop
    # nop
    # nop
    # nop
    # lw x7 0xC(x3)
    ##################
    print("\n\nTESTING JAL\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.pc.value) == "00000048"

    await NextInstr(dut) # jal x1 (to lw instruction below)
    
    await NextInstr(dut) # lw x7 0xC(x3)
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "DEADBEEF"
    
    ##################
    # ADDI TEST
    # addi x26 x7 0x1AB   | x26 <= DEADC09A
    # addi x25 x6 0xF21   | x25 <= DEADBE10
    ##################
    print("\n\nTESTING ADDI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "1AB38D13"
    assert not binary_to_hex(dut.core.regfile.registers[26].value) == "DEADC09A"

    await NextInstr(dut) # addi x26 x7 0x1AB
    assert binary_to_hex(dut.core.regfile.registers[26].value) == "DEADC09A"

    await NextInstr(dut) # NOP

    ##################
    # AUIPC TEST (PC befor is 0x64)
    # auipc x5 0x1F1FA    | x5 <= 1F1FA068      PC 0x68
    ##################
    print("\n\nTESTING AUIPC\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "1F1FA297"

    await NextInstr(dut) # auipc x5 0x1F1FA
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "1F1FA068"

    ##################
    # LUI TEST
    # lui x5 0x2F2FA      | x5 <= 2F2FA000
    ##################
    print("\n\nTESTING LUI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "2F2FA2B7"

    await NextInstr(dut) # lui x5 0x2F2FA 
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "2F2FA000"

    ##################
    # nop
    # slti x23 x23 0x001  | x23 <= 00000001
    ##################
    print("\n\nTESTING SLTI\n\n")

    await NextInstr(dut) # nop

    await NextInstr(dut) # slti x23 x23 0x001
    assert binary_to_hex(dut.core.regfile.registers[23].value) == "00000001"

    ##################
    # nop
    # sltiu x22 x19 0x001 | x22 <= 00000000
    ##################
    print("\n\nTESTING SLTIU\n\n")

    await NextInstr(dut) # nop

    await NextInstr(dut) # sltiu x22 x19 0x001 
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "00000000"

    ##################
    # nop
    # xori x19 x18 0x000
    ##################
    print("\n\nTESTING XORI\n\n")

    await NextInstr(dut) # nop

    await NextInstr(dut) # xori x19 x18 0x000 
    assert binary_to_hex(dut.core.regfile.registers[19].value) == binary_to_hex(dut.core.regfile.registers[18].value)

    ##################
    # nop
    # ori x21 x20 0x000
    ##################
    print("\n\nTESTING ORI\n\n")

    await NextInstr(dut) # nop

    await NextInstr(dut) # ori x21 x20 0x000
    assert binary_to_hex(dut.core.regfile.registers[21].value) == binary_to_hex(dut.core.regfile.registers[20].value)

    ##################
    # andi x18 x20 0x7FF 
    # nop
    # andi x20 x21 0x000
    ##################
    print("\n\nTESTING ANDI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "7FFA7913"

    await NextInstr(dut) # andi x18 x20 0x7FF
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "00000199"

    await NextInstr(dut) # nop

    await NextInstr(dut) # andi x20 x21 0x000 
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "00000000"
    
    ##################
    # slli x19 x19 0x4 
    # NOP
    ##################
    print("\n\nTESTING SLLI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00499993"

    await NextInstr(dut) # slli x19 x19 0x4
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "EADBEEF0"

    await NextInstr(dut) # NOP

    ##################
    # srli x20 x19 0x4 
    # NOP
    ##################
    print("\n\nTESTING SRLI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "0049DA13"

    await NextInstr(dut) # srli x20 x19 0x4
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "0EADBEEF"

    await NextInstr(dut) # NOP


    ##################
    # srai x21 x21 0x4 
    # NOP
    ##################
    print("\n\nTESTING SRAI\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "404ADA93"

    await NextInstr(dut) # srai x21 x21 0x4
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "FDEADC99"

    await NextInstr(dut) # NOP

    ##################
    # sub x18 x21 x18 
    ##################
    print("\n\nTESTING SUB\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "412A8933"

    await NextInstr(dut) # sub x18 x21 x18
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FDEADB00"
    
    ##################
    # addi x7 x0 0x8
    # sll x18 x18 x7
    ##################
    print("\n\nTESTING SLL\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00800393"

    await NextInstr(dut) # addi x7 x0 0x8
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00000008"

    await NextInstr(dut) # sll x18 x18 x7
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "EADB0000"
    
    ##################
    # slt x17 x22 x23
    ##################
    print("\n\nTESTING SLT\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "017B28B3"

    await NextInstr(dut) # slt x17 x22 x23
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "00000001"
    
    ##################
    # sltu x17 x22 x23 
    ##################
    print("\n\nTESTING SLTU\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "017B38B3"

    await NextInstr(dut) # sltu x17 x22 x23
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "00000001"
    
    ##################
    # xor x17 x18 x19
    ##################
    print("\n\nTESTING XOR\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "013948B3"

    await NextInstr(dut) # xor x17 x18 x19
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "0000EEF0"

    ##################
    # srl x8 x19 x7
    ##################
    print("\n\nTESTING SRL\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "0079D433"

    await NextInstr(dut) # srl x8 x19 x7
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "00EADBEE"

    ##################
    # sra x8 x19 x7
    ##################
    print("\n\nTESTING SRA\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "4079D433"

    await NextInstr(dut) # sra x8 x19 x7 
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"
    
    ##################
    # blt x17 x8 0x8      | not taken : x8 neg (sign), x17 pos (no sign)
    # blt x8 x17 0x8      | taken : x8 neg (sign), x17 pos (no sign)
    # addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BLT\n\n")

    # execute, branch should NOT be taken !
    await NextInstr(dut) # blt x17 x8 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "01144463"

    # execute, branch SHOULD be taken !
    await NextInstr(dut) # blt x8 x17 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"

    ##################
    # bne x8 x8 0x8  
    # bne x8 x17 0x8 
    # addi x8 x0 0xC 
    ##################
    print("\n\nTESTING BNE\n\n")

    # execute, branch should NOT be taken !
    await NextInstr(dut) # bne x8 x8 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "01141463"

    # execute, branch SHOULD be taken !
    await NextInstr(dut) # bne x8 x17 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"

    ##################
    # bge x8 x17 0x8     
    # bge x8 x8 0x8      
    # addi x8 x0 0xC   
    ##################
    print("\n\nTESTING BGE\n\n")

    # execute, branch should NOT be taken !
    await NextInstr(dut) # bge x8 x17 0x8 
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00845463"

    # execute, branch SHOULD be taken !
    await NextInstr(dut) # bge x8 x8 0x8 
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"

    ##################
    # bltu x8 x17 0x8    
    # bltu x17 x8 0x8    
    # addi x8 x0 0xC   
    ##################
    print("\n\nTESTING BLTU\n\n")

    # execute, branch should NOT be taken !
    await NextInstr(dut) # bltu x8 x17 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "0088E463"

    # execute, branch SHOULD be taken !
    await NextInstr(dut) # bltu x17 x8 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"

    ##################
    # bgeu x17 x8 0x8 
    # bgeu x8 x17 0x8    
    # addi x8 x0 0xC     
    ##################
    print("\n\nTESTING BGEU\n\n")

    # execute, branch should NOT be taken !
    await NextInstr(dut) # bgeu x17 x8 0x8
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "01147463"

    # execute, branch SHOULD be taken !
    await NextInstr(dut) # bgeu x8 x17 0x8 
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"

    ##################
    # auipc x7 0x0    
    # addi x7 x7 0x14 
    # jalr x1  -4(x7) 
    # addi x8 x0 0xC  
    ##################
    print("\n\nTESTING JALR\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00000397"
    assert binary_to_hex(dut.core.pc.value) == "00000110"

    await NextInstr(dut)# auipc x7 0x00
    await NextInstr(dut) # addi x7 x7 0x10 
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00000124"

    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "FFC380E7"

    await NextInstr(dut) # jalr x1  -4(x7)

    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.regfile.registers[1].value) == "0000011C"
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFEADBEE"
    assert binary_to_hex(dut.core.pc.value) == "00000120"

    #################
    # nop
    # sb x8 0x6(x3)
    ##################
    print("\n\nTESTING SB\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00000013"

    await NextInstr(dut) # nop

    await NextInstr(dut) # sb x8 0x6(x3)
    assert int.from_bytes(axi_lite_ram_slave.read(0x1004, 4), byteorder="little") == 0x00EE_0000

    #################
    # nop
    # nop
    # sh x8 6(x3)
    # NOTE : misaligned stores throws an excption
    # and these tests are covered by riscof and not
    # here anymore, thus the nop placeholder
    ##################
    print("\n\nTESTING SH\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "00000013"

    
    await NextInstr(dut) # nop
    await NextInstr(dut) # nop

    await NextInstr(dut) # sh x8 6(x3) 

    # axi_lite_ram_slave.hexdump(0x1004,4)
    # print(hex(int.from_bytes(axi_lite_ram_slave.read(0x1004, 4), byteorder="little")))

    # print(hex(int.from_bytes(axi_lite_ram_slave.read(0x1004, 4), byteorder="little")))
    assert int.from_bytes(axi_lite_ram_slave.read(0x1004, 4), byteorder="little") == 0xDBEE0000

    #################
    # PARTIAL LOADS
    # addi x7 x3 0x10
    # nop
    # lb x18 -1(x7)  
    # lbu x19 -3(x7) 
    # nop 
    # lh x20 -6(x7)  
    # nop 
    # lhu x21 -6(x7) 
    # NOTE : misaligned loads throws an excption
    # and these tests are covered by riscof and not
    # here anymore, thus the nop placeholder
    ##################
    print("\n\nTESTING LB\n\n")

    # Check test's init state
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)
    assert binary_to_hex(dut.core.instruction.value) == "01018393"

    await NextInstr(dut) # addi x7 x3 0x10 
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00001010"
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "EADB0000"

    await NextInstr(dut) # nop

    await NextInstr(dut) # lb x18 -1(x7) 
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFFFFFDE"

    await NextInstr(dut) # lbu x19 -3(x7)
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "000000BE"

    await NextInstr(dut) # nop

    await NextInstr(dut) # lh x20 -6(x7)
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "FFFFDEAD"

    await NextInstr(dut) # nop

    await NextInstr(dut) # lhu x21 -6(x7)
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "0000DEAD"

    #################
    # CACHE WB TEST
    # addi x7 x3 0x200  / x7  <= 00001200 (just above 128*4=512B cache size)
    # lw x20 0x0(x7)    / MISS + WRITE BACK + RELOAD !
    ##################

    if dut.core.DCACHE_EN.value:
        # Check test's init state
        while(dut.core.stall.value == 1) :
            await RisingEdge(dut.clk)
        assert binary_to_hex(dut.core.instruction.value) == "20018393"

        await NextInstr(dut) # addi x7 x3 0x200
        assert binary_to_hex(dut.core.regfile.registers[7].value) == "00001200"

        assert dut.core.stall.value == 0b1
        assert dut.core.gen_data_cache.data_cache.next_state.value == SENDING_WRITE_REQ

        # Wait for the cache to retrieve data
        await NextInstr(dut) # lw x20 0x0(x7)
        assert binary_to_hex(dut.core.regfile.registers[20].value) == "00000000"
        assert axi_ram_slave.read(0x00001004, 4) == 0xFFEE0000.to_bytes(4,'little')
    
    else :
        # this test is not relevant if we disable the cache, we skip it
        while binary_to_hex(dut.core.pc) != "0000015C":
            await RisingEdge(dut.clk)

    #################
    # CSR TESTS (FLUSH_CACHE)
    # addi x20 x0 0x1    
    # csrrw x21 0x7C0 x20
    ##################

    if dut.core.DCACHE_EN.value:
        # Check test init's state
        while(dut.core.stall.value == 1) :
            await RisingEdge(dut.clk)
        assert binary_to_hex(dut.core.regfile.registers[21].value) == "0000DEAD"
        assert binary_to_hex(dut.core.instruction.value) == "00100A13"
        assert binary_to_hex(dut.core.pc) == "0000015C"

        await NextInstr(dut) # addi x20 x0 0x1
        assert binary_to_hex(dut.core.regfile.registers[20].value) == "00000001"
        assert binary_to_hex(dut.core.pc) == "00000160"
        
        await NextInstr(dut) # csrrw x21 0x7C0 x20
        await Timer(2,units="ns") # csrrw x21 0x7C0 x20
        assert binary_to_hex(dut.core.regfile.registers[21].value) == "00000000" # value in CSR was 0...
        
        assert dut.core.stall.value == 0b1
        assert dut.core.gen_data_cache.data_cache.state.value == SENDING_WRITE_REQ

        # Wait for the cache to retrieve data
        while(dut.core.stall.value == 0b1) :
            await RisingEdge(dut.clk)

        # At the end of the stall, CSR should be back to 0
        assert dut.core.stall.value == 0b0
        assert binary_to_hex(dut.core.holy_csr_file.flush_cache.value) == "00000000"
        assert binary_to_hex(dut.core.pc) == "00000164"
    else :
        # this test is not relevant if we disable the cache, we skip it
        while binary_to_hex(dut.core.instruction) != "00000A13":
            await RisingEdge(dut.clk)

    #################
    # CSR & CACHE TESTS (UNCACHABLE RANGE SETTING)
    # addi x20 x0 0x0    
    # lui x20 0x2        
    # addi x21 x20 0x200 
    # csrrw x0 0x7C1 x20 
    # csrrw x0 0x7C2 x21 
    # addi x20 x20 0x4   
    # lui x22 0xABCD1    
    # addi x22 x22 0x111 
    # sw x22 0(x20)      
    # lw x22 4(x20)      
    # lw x22 0(x20)      
    ##################

    if dut.core.DCACHE_EN.value:
        # check init state
        while(dut.core.stall.value == 1) :
            await RisingEdge(dut.clk)
        assert binary_to_hex(dut.core.instruction.value) == "00000A13"

        # generate constants
        await NextInstr(dut) # addi x20 x0 0x0
        await NextInstr(dut) # lui x20 0x2
        await NextInstr(dut) # addi x21 x20 0x200
        await Timer(1, units="ns")

        assert binary_to_hex(dut.core.regfile.registers[20].value) == "00002000"
        assert binary_to_hex(dut.core.regfile.registers[21].value) == "00002200"

        # write the CRSs
        await NextInstr(dut) # csrrw x0 0x7C1 x20
        await NextInstr(dut) # csrrw x0 0x7C2 x21
        await Timer(1, units="ns")

        assert binary_to_hex(dut.core.holy_csr_file.non_cachable_base.value) == "00002000"
        assert binary_to_hex(dut.core.holy_csr_file.non_cachable_limit.value) == "00002200"

        # generate addr & write data constant
        await NextInstr(dut) # addi x20 x20 0x4
        await NextInstr(dut) # lui x22 0xABCD1
        await NextInstr(dut) # addi x22 x22 0x111

        assert binary_to_hex(dut.core.regfile.registers[20].value) == "00002004"
        assert binary_to_hex(dut.core.regfile.registers[22].value) == "ABCD1111"

        # make sure data is initialy 0 where we'll test
        axi_lite_ram_slave.write(0x0000_2004, int(0x0000_0000).to_bytes(4, 'little'))
        axi_lite_ram_slave.write(0x0000_2008, int(0x0000_0000).to_bytes(4, 'little'))

        # -----------------------------------
        # WRITE TO "MMIO SLAVE" (RAM in this TB) USING AXI LITE

        assert dut.core.stall.value == 0b1
        assert dut.core.gen_data_cache.data_cache.non_cachable.value == 0b1
        await RisingEdge(dut.clk) # do not execute...

        # core shouls be in  AXI_LITE TRANSACTION
        assert dut.core.gen_data_cache.data_cache.state.value == LITE_SENDING_WRITE_REQ

        # we wait until its done
        while dut.core.stall.value == 0b1:
            await RisingEdge(dut.clk)

        # check that data has been written
        assert axi_lite_ram_slave.read(0x0000_2004, 4) == (0xABCD1111).to_bytes(4, "little")
        assert dut.core.stall.value == 0b0

        # -----------------------------------
        # READ MMIO SLAVE USING AXI LITE

        await NextInstr(dut) # EXECUTED sw x22 0(x20), FETCHING lw x22 4(x20)

        assert dut.core.stall.value == 0b1
        assert dut.core.gen_data_cache.data_cache.non_cachable.value == 0b1

        # core should be about to go to AXI_LITE TRANSACTION
        assert dut.core.gen_data_cache.data_cache.next_state.value == LITE_SENDING_READ_REQ

        # we wait until its done
        while dut.core.stall.value == 0b1:
            await RisingEdge(dut.clk)

        await NextInstr(dut) # EXECUTED lw x22 4(x20), FETCHING lw x22 0(x20)

        assert binary_to_hex(dut.core.regfile.registers[22].value) == "00000000"


        # -----------------------------------
        # READ MMIO SLAVE USING AXI LITE

        assert dut.core.stall.value == 0b1
        assert dut.core.gen_data_cache.data_cache.non_cachable.value == 0b1

        # core should be about to go to AXI_LITE TRANSACTION
        assert dut.core.gen_data_cache.data_cache.next_state.value == LITE_SENDING_READ_REQ

        # we wait until its done
        while dut.core.stall.value == 0b1:
            await RisingEdge(dut.clk)

        await NextInstr(dut) # EXECUTED lw x22 0(x20)

        assert binary_to_hex(dut.core.regfile.registers[22].value) == "ABCD1111"

    #################
    # SOFTWARE INTERRUPT TEST
    #################

    # Interrupts tests are pretty straight forward. The behavior
    # should be an interrupt assertion, followed by an mret
    # at some point, after which interrupt is vleared by the handler.
    # Meeting these conditions, along some other additional checks
    # Ensures basic bahavior is okay.

    # We set the MIE csr, activate all interrupts (note: now we do it using actual instrs)
    # dut.core.holy_csr_file.mie.value = 1 << 3 | 1 << 7 | 1 << 11
    # dut.core.holy_csr_file.mstatus.value = 1 << 3

    # Wait until we are about to write 1 to software interrupt
    while not binary_to_hex(dut.core.instruction.value) == "00522023":
        await RisingEdge(dut.clk)
    
    while dut.core.stall.value == 0b1:
        await RisingEdge(dut.clk) # sw x5 0(x4)
    
    # a software interrupt should be raised
    assert dut.clint.soft_irq.value == 1
    assert dut.core.trap.value == 1

    # wait until we are about to mret
    while not binary_to_hex(dut.core.instruction.value) == "30200073":
        await RisingEdge(dut.clk) # mret

    # check that x3° was signed with the right mcause by handler
    assert binary_to_hex(dut.core.regfile.registers[30].value) == "80000003"
    
    #################
    # TIMER INTERRUPT TEST
    #################

    # Wait until we have a timer irq
    while dut.core.timer_itr.value != 1:
        await RisingEdge(dut.clk)

    # wait until we are about to mret
    while not binary_to_hex(dut.core.instruction.value) == "30200073":
        await RisingEdge(dut.clk) # mret

    # timer interrupt is cleared
    assert dut.core.timer_itr.value == 0

    # mcause saved in x30 is the right one
    assert binary_to_hex(dut.core.regfile.registers[30].value) == "80000007"

    #################
    # EXTERNAL INTERRUPT TEST
    #################

    # in this scerio, we will imagine a simple peripheral
    # that latches an interrupt until the CPU enters its hadler
    # and we'll deassert the said interrupt when the CPU executes
    # a NOP. The NOP is a placeholder here that replaces a sequance
    # that interacts with the peripheral (e.g. reading a sensor's
    # register via I2C to retrieve its data in memeory). We do this
    # because we do not simulate any *actual* SoC Level / PCB Level
    # peripheral in this testbench.

    # Wait for previous mret to finish (instr cache may be pulling data)
    while binary_to_hex(dut.core.instruction.value) == "30200073":
        await RisingEdge(dut.clk)

    # wait until ext irq waiting loop
    while not binary_to_hex(dut.core.instruction.value) == "0000006F":
        await RisingEdge(dut.clk)

    # Introduce an external itr request in the PLIC
    dut.irq_in[0].value = 1

    # wait until plic asserts that interrupt
    while not dut.core.ext_itr.value == 1:
        await RisingEdge(dut.clk)

    # wait until we are about to mret
    while not binary_to_hex(dut.core.instruction.value) == "30200073":
        # NOP is our placeholder to deassert the interrupt request
        if binary_to_hex(dut.core.instruction.value) == "00000013":
            dut.irq_in[0].value = 0
        await RisingEdge(dut.clk)
    
    # check that the interrupt is cleared
    assert dut.core.ext_itr.value == 0
    # mcause saved in x30 is the right one
    assert binary_to_hex(dut.core.regfile.registers[30].value) == "8000000B"

    #################
    # ECALL EXCEPTION TEST
    #################

    # wait for ecall to be fetched
    while not binary_to_hex(dut.core.instruction.value) == "00000073":
        await RisingEdge(dut.clk)

    assert dut.core.exception.value == 1
    assert dut.core.trap.value == 1
    
    # wait until we are about to mret
    while not binary_to_hex(dut.core.instruction.value) == "30200073":
        await RisingEdge(dut.clk)

    assert dut.core.exception.value == 0
    assert dut.core.trap.value == 0

    assert binary_to_hex(dut.core.regfile.registers[30].value) == "0000000B"

    #################
    # DEBUG REQUEST TEST
    #################

    # we use this this NOP (00000013) to mark the beginning of the debug test
    while not binary_to_hex(dut.core.instruction.value) == "00000013":
        await RisingEdge(dut.clk)
        print("hey")

    # send a debug request
    dut.core.debug_halt_addr.value = dut.core.regfile.registers[5].value
    halt_value = dut.core.regfile.registers[5].value
    dut.core.debug_exception_addr.value = dut.core.regfile.registers[6].value
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.core.debug_req.value = 1
    await Timer(3, units="ns")

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)

    # wait to switch to debug mode
    while not dut.core.holy_csr_file.debug_mode.value == 1:
        # save the last known pc to later check is dpc saves it well
        pc_save = dut.core.pc.value
        await RisingEdge(dut.clk)

    # wait for ebreak
    while not binary_to_hex(dut.core.instruction.value) == "00100073":
        assert dut.core.holy_csr_file.debug_mode.value == 1
        await RisingEdge(dut.clk)
    
    # RV debug specs : "When ebreak is executed (indicating the end
    # of the Program Buffer code) the hart returns to its park loop.
    # If an exception is encountered, the hart jumps to a debug
    # exception address within the Debug Module."
    await NextInstr(dut)
    assert dut.core.pc.value == halt_value

    # wait for dret
    while not binary_to_hex(dut.core.instruction.value) == "7B200073":
        assert dut.core.holy_csr_file.debug_mode.value == 1
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)
    assert dut.core.holy_csr_file.dpc.value == pc_save
    assert dut.core.holy_csr_file.debug_mode.value == 0
    dut.core.debug_req.value = 0

    await Timer(500, units="ns")