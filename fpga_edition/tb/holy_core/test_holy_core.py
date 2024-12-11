# HOLY_CORE TESTBECH
#
# Uses a pre-made hardcoded HEX program.
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam
import numpy as np

# WARNING : Passing test on async cloks does not means timing sync is met !
AXI_PERIOD = 10
CPU_PERIOD = 10

# CACHE STATES CST
IDLE                = 0b000
SENDING_WRITE_REQ   = 0b001
SENDING_WRITE_DATA  = 0b010
WAITING_WRITE_RES   = 0b011
SENDING_READ_REQ    = 0b100
RECEIVING_READ_DATA = 0b101

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
    # ==============
    # 0x1FFF
    # Data
    # 0x1000 (stored in gp : x3)
    # ==============
    # 0x0FFF
    # Instructions
    # 0x0000
    #===============

    SIZE = 2**13
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)

    await cpu_reset(dut)
    await init_memory(axi_ram_slave, "./test_imemory.hex", 0x0000)
    await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)

    ##################
    # SAVE BASE ADDR IN X3
    # 00000193  //DATA ADDR STORE                         | x3  <= 00001000
    ##################
    print("\n\nSAVING DATA BASE ADDR\n\n")

    # Wait a clock cycle for the instruction to execute
    while(dut.core.stall.value == 1) :
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk) # lui x3 0x1
    # Check the value of reg x18
    assert binary_to_hex(dut.core.regfile.registers[3].value) == "00001000"

    ##################
    # LOAD WORD TEST 
    # 0081A903  //LW  TEST START :    lw x18 0x8(x3)      | x18 <= DEADBEEF
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
    # 0121A623  //SW  TEST START :    sw x18 0xC(x3)      | 0xC <= DEADBEEF
    ##################
    print("\n\nTESTING SW\n\n")
    test_address = int(0xC / 4) 

    # Check the inital state
    # assert binary_to_hex(dut.core.data_cache.cache_data[test_address].value) == "F2F2F2F2"
    assert read_cache(dut.core.data_cache.cache_data, test_address) == int("F2F2F2F2",16)

    await RisingEdge(dut.clk) # sw x18 0xC(x3)
    assert read_cache(dut.core.data_cache.cache_data, test_address) == int("DEADBEEF",16)

    ##################
    # ADD TEST
    # 0101A983  //ADD TEST START :    lw x19 0x10(x3)     | x19 <= 00000AAA
    # 01390A33  //                    add x20 x18 x19     | x20 <= DEADC999
    ##################
    print("\n\nTESTING ADD\n\n")

    # Expected result of x18 + x19
    expected_result = (0xDEADBEEF + 0x00000AAA) & 0xFFFFFFFF
    await RisingEdge(dut.clk) # lw x19 0x10(x3)
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "00000AAA"
    await RisingEdge(dut.clk) # add x20 x18 x19
    assert dut.core.regfile.registers[20].value == expected_result

    ##################
    # AND TEST
    # and x21 x18 x20 (result shall be 0xDEAD8889)
    ##################
    print("\n\nTESTING AND\n\n")

    # Use last expected result, as this instr uses last op result register
    expected_result = expected_result & 0xDEADBEEF
    await RisingEdge(dut.clk) # and x21 x18 x20
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "DEAD8889"

    ##################
    # OR TEST
    # For this one, I decider to load some more value to change the "0xdead.... theme" ;)
    # 0141A283  //OR  TEST START :    lw x5 0x14(x3)      | x5  <= 125F552D
    # 0181A283  //                    lw x6 0x18(x3)      | x6  <= 7F4FD46A
    # 0062E3B3  //                    or x7 x5 x6         | x7  <= 7F5FD56F
    ##################
    print("\n\nTESTING OR\n\n")

    await RisingEdge(dut.clk) # lw x5 0x14(x3) | x5  <= 125F552D
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "125F552D"
    await RisingEdge(dut.clk) # lw x6 0x18(x3) | x6  <= 7F4FD46A
    assert binary_to_hex(dut.core.regfile.registers[6].value) == "7F4FD46A"
    await RisingEdge(dut.clk) # or x7 x5 x6    | x7  <= 7F5FD56F
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "7F5FD56F"

    ##################
    # BEQ TEST
    # 00730663  //BEQ TEST START :    beq x6 x7 0xC       | #1 SHOULD NOT BRANCH
    # 0081AB03  //                    lw x22 0x8(x3)      | x22 <= DEADBEEF
    # 01690863  //                    beq x18 x22 0x10    | #2 SHOULD BRANCH (+ offset)
    # 00000013  //                    nop                 | NEVER EXECUTED
    # 00000013  //                    nop                 | NEVER EXECUTED
    # 00000663  //                    beq x0 x0 0xC       | #4 SHOULD BRANCH (avoid loop)
    # 0001AB03  //                    lw x22 0x0(x3)      | x22 <= AEAEAEAE
    # FF6B0CE3  //                    beq x22 x22 -0x8    | #3 SHOULD BRANCH (-offset)
    # 00000013  //                    nop                 | FINAL NOP
    ##################
    print("\n\nTESTING BEQ\n\n")

    assert binary_to_hex(dut.core.instruction.value) == "00730663"

    await RisingEdge(dut.clk) # beq x6 x7 0xC NOT TAKEN
    assert binary_to_hex(dut.core.instruction.value) == "0081AB03"

    await RisingEdge(dut.clk) # lw x22 0x8(x3)
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "DEADBEEF"

    await RisingEdge(dut.clk) # beq x18 x22 0x10 TAKEN
    assert binary_to_hex(dut.core.instruction.value) == "0001AB03"

    await RisingEdge(dut.clk) # lw x22 0x0(x3)
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "AEAEAEAE"

    await RisingEdge(dut.clk) # beq x22 x22 -0x8 TAKEN
    assert binary_to_hex(dut.core.instruction.value) == "00000663"

    await RisingEdge(dut.clk) # beq x0 x0 0xC TAKEN
    assert binary_to_hex(dut.core.instruction.value) == "00000013"
    await RisingEdge(dut.clk) # NOP

    ##################
    # 00C000EF  //JAL TEST START :    jal x1 0xC          | #1 jump @PC+0xC     PC 0x48
    # 00000013  //                    nop                 | NEVER EXECUTED      PC 0x4C
    # 00C000EF  //                    jal x1 0xC          | #2 jump @PC-0x4     PC 0x50
    # FFDFF0EF  //                    jal x1 0x-4         | #2 jump @PC-0x4     PC 0x54
    # 00000013  //                    nop                 | NEVER EXECUTED      PC 0x58
    # 00C1A383  //                    lw x7 0xC(x3)       | x7 <= DEADBEEF      PC 0x5C
    ##################
    print("\n\nTESTING JAL\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "00C000EF"
    assert binary_to_hex(dut.core.pc.value) == "00000048"

    await RisingEdge(dut.clk) # jal x1 0xC
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.core.instruction.value) == "FFDFF0EF"
    assert binary_to_hex(dut.core.pc.value) == "00000054"
    assert binary_to_hex(dut.core.regfile.registers[1].value) == "0000004C" # stored old pc + 4

    await RisingEdge(dut.clk) # jal x1 -4
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.core.instruction.value) == "00C000EF"
    assert binary_to_hex(dut.core.pc.value) == "00000050"
    assert binary_to_hex(dut.core.regfile.registers[1].value) == "00000058" # stored old pc + 4

    await RisingEdge(dut.clk) # jal x1 0xC
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.core.instruction.value) == "00C1A383"
    assert binary_to_hex(dut.core.pc.value) == "0000005C"
    assert binary_to_hex(dut.core.regfile.registers[1].value) == "00000054" # stored old pc + 4

    await RisingEdge(dut.clk) # lw x7 0xC(x3)
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "DEADBEEF"
    
    ##################
    # ADDI TEST
    # 1AB38D13  //                    addi x26 x7 0x1AB   | x26 <= DEADC09A
    # F2130C93  //                    addi x25 x6 0xF21   | x25 <= DEADBE10
    ##################
    print("\n\nTESTING ADDI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "1AB38D13"
    assert not binary_to_hex(dut.core.regfile.registers[26].value) == "DEADC09A"

    await RisingEdge(dut.clk) # addi x26 x7 0x1AB
    assert binary_to_hex(dut.core.instruction.value) == "F2130C93"
    assert binary_to_hex(dut.core.regfile.registers[26].value) == "DEADC09A"

    await RisingEdge(dut.clk) # addi x25 x6 0xF21
    assert binary_to_hex(dut.core.regfile.registers[25].value) == "7F4FD38B"

    ##################
    # AUIPC TEST (PC befor is 0x64)
    # 1F1FA297  //AUIPC TEST START :  auipc x5 0x1F1FA    | x5 <= 1F1FA068      PC 0x68
    ##################
    print("\n\nTESTING AUIPC\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "1F1FA297"

    await RisingEdge(dut.clk) # auipc x5 0x1F1FA
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "1F1FA068"

    ##################
    # LUI TEST
    # 2F2FA2B7  //LUI TEST START :    lui x5 0x2F2FA      | x5 <= 2F2FA000
    ##################
    print("\n\nTESTING LUI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "2F2FA2B7"

    await RisingEdge(dut.clk) # lui x5 0x2F2FA 
    assert binary_to_hex(dut.core.regfile.registers[5].value) == "2F2FA000"

    ##################
    # FFF9AB93  //SLTI TEST START :   slti x23 x19 0xFFF  | x23 <= 00000000
    # 001BAB93  //                    slti x23 x23 0x001  | x23 <= 00000001
    ##################
    print("\n\nTESTING SLTI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "00000AAA"
    assert binary_to_hex(dut.core.instruction.value) == "FFF9AB93"

    await RisingEdge(dut.clk) # slti x23 x19 0xFFF
    assert binary_to_hex(dut.core.regfile.registers[23].value) == "00000000"

    await RisingEdge(dut.clk) # slti x23 x23 0x001
    assert binary_to_hex(dut.core.regfile.registers[23].value) == "00000001"

    ##################
    # FFF9BB13  //SLTIU TEST START :  sltiu x22 x19 0xFFF | x22 <= 00000001
    # 0019BB13  //                    sltiu x22 x19 0x001 | x22 <= 00000000
    ##################
    print("\n\nTESTING SLTIU\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "FFF9BB13"

    await RisingEdge(dut.clk) # sltiu x22 x19 0xFFF
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "00000001"

    await RisingEdge(dut.clk) # sltiu x22 x19 0x001 
    assert binary_to_hex(dut.core.regfile.registers[22].value) == "00000000"

    ##################
    # AAA94913  //XORI TEST START :   xori x18 x18 0xAAA  | x18 <= 21524445 (because sign extend)
    # 00094993  //                    xori x19 x18 0x000  | x19 <= 21524445
    ##################
    print("\n\nTESTING XORI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "AAA94913"

    await RisingEdge(dut.clk) # xori x18 x19 0xAAA 
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "21524445"

    await RisingEdge(dut.clk) # xori x19 x18 0x000 
    assert binary_to_hex(dut.core.regfile.registers[19].value) == binary_to_hex(dut.core.regfile.registers[18].value)

    ##################
    # AAA9EA13  //ORI TEST START :    ori x20 x19 0xAAA   | x20 <= FFFFFEEF
    # 000A6A93  //                    ori x21 x20 0x000   | x21 <= FFFFFEEF
    ##################
    print("\n\nTESTING ORI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "AAA9EA13"

    await RisingEdge(dut.clk) # ori x20 x19 0xAAA 
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "FFFFFEEF"

    await RisingEdge(dut.clk) # ori x21 x20 0x000
    assert binary_to_hex(dut.core.regfile.registers[21].value) == binary_to_hex(dut.core.regfile.registers[20].value)

    ##################
    # 7FFA7913  //ANDI TEST START :   andi x18 x20 0x7FF  | x18 <= 000006EF
    # FFFAF993  //                    andi x19 x21 0xFFF  | x19 <= FFFFFEEF
    # 000AFA13  //                    andi x20 x21 0x000  | x20 <= 00000000
    ##################
    print("\n\nTESTING ANDI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "7FFA7913"

    await RisingEdge(dut.clk) # andi x18 x20 0x7FF 
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "000006EF"

    await RisingEdge(dut.clk) # andi x19 x21 0xFFF
    assert binary_to_hex(dut.core.regfile.registers[19].value) == binary_to_hex(dut.core.regfile.registers[21].value)
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "FFFFFEEF"

    await RisingEdge(dut.clk) # andi x20 x21 0x000 
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "00000000"
    
    ##################
    # 00499993  //SLLI TEST START :   slli x19 x19 0x4    | x19 <= FFFFEEF0
    # 02499993  //                    invalid op test     | NO CHANGE ! (wrong "F7" for SL)
    ##################
    print("\n\nTESTING SLLI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "00499993"

    await RisingEdge(dut.clk) # slli x19 x19 0x4
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "FFFFEEF0"

    # the op is invalid ! reg_write should be 0 in order not to alter CPU state
    assert dut.core.reg_write.value == "0" 
    await RisingEdge(dut.clk) # invalid op test
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "FFFFEEF0"

    ##################
    # 0049DA13  //SRLI TEST START :   srli x20 x19 0x4    | x20 <= 0FFFFEEF
    # 0249DA13  //                    invalid op test     | NO CHANGE ! (wrong "F7" for SR)
    ##################
    print("\n\nTESTING SRLI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "0049DA13"

    await RisingEdge(dut.clk) # srli x20 x19 0x4
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "0FFFFEEF"

    # the op is invalid ! reg_write should be 0 in order not to alter CPU state
    assert dut.core.reg_write.value == "0" 
    await RisingEdge(dut.clk) # invalid op test
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "0FFFFEEF"

    ##################
    # 404ADA93  //SRAI TEST START :   srai x21 x21 0x4    | x21 <= FFFFFFEE
    # 424ADA93  //                    invalid op test     | NO CHANGE ! (wrong "F7" for SR)
    ##################
    print("\n\nTESTING SRAI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "404ADA93"

    await RisingEdge(dut.clk) # srai x21 x21 0x4
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "FFFFFFEE"

    # the op is invalid ! reg_write should be 0 in order not to alter CPU state
    assert dut.core.reg_write.value == "0" 
    await RisingEdge(dut.clk) # invalid op test
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "FFFFFFEE"

    ##################
    # 412A8933  //SUB TEST START :    sub x18 x21 x18     | x18 <= FFFFF8FF
    ##################
    print("\n\nTESTING SUB\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "412A8933"

    await RisingEdge(dut.clk) # sub x18 x21 x18
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFFFF8FF"
    
    ##################
    # 00800393  //SLL TEST START :    addi x7 x0 0x8      | x7  <= 00000008
    # 00791933  //                    sll x18 x18 x7      | x18 <= FFF8FF00
    ##################
    print("\n\nTESTING SLL\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "00800393"
    await RisingEdge(dut.clk) # addi x7 x0 0x8
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00000008"

    await RisingEdge(dut.clk) # sll x18 x18 x7
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFF8FF00"
    
    ##################
    # 013928B3  //SLT TEST START :    slt x17 x22 x23     | x17 <= 00000001 (-459008 < -4368)
    ##################
    print("\n\nTESTING SLT\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "013928B3"

    await RisingEdge(dut.clk) # slt x17 x22 x23
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "00000001"
    
    ##################
    # 013938B3  //SLTU TEST START :   sltu x17 x22 x23    | x17 <= 00000001
    ##################
    print("\n\nTESTING SLTU\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "013938B3"

    await RisingEdge(dut.clk) # sltu x17 x22 x23
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "00000001"
    
    ##################
    # 013948B3  //XOR TEST START :    xor x17 x18 x19     | x17 <= 000711F0
    ##################
    print("\n\nTESTING XOR\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "013948B3"

    await RisingEdge(dut.clk) # xor x17 x18 x19
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "000711F0"

    ##################
    # 0079D433  //SRL TEST START :    srl x8 x19 x7       | x8  <= 00FFFFEE
    ##################
    print("\n\nTESTING SRL\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "0079D433"

    await RisingEdge(dut.clk) # srl x8 x19 x7
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "00FFFFEE"

    ##################
    # 4079D433  //SRA TEST START :    sra x8 x19 x7       | x8  <= FFFFFFEE
    ##################
    print("\n\nTESTING SRA\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "4079D433"

    await RisingEdge(dut.clk) # sra x8 x19 x7 
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"
    
    ##################
    # 0088C463  //BLT TEST START :    blt x17 x8 0x8      | not taken : x8 neg (sign), x17 pos (no sign)
    # 01144463  //                    blt x8 x17 0x8      | taken : x8 neg (sign), x17 pos (no sign)
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BLT\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "0088C463"
    assert binary_to_hex(dut.core.regfile.registers[17].value) == "000711F0"
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    # execute, branch should NOT be taken !
    await RisingEdge(dut.clk) # blt x17 x8 0x8
    assert binary_to_hex(dut.core.instruction.value) == "01144463"

    # execute, branch SHOULD be taken !
    await RisingEdge(dut.clk) # blt x8 x17 0x8
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    ##################
    # 00841463  //BNE TEST START :    bne x8 x8 0x8       | not taken
    # 01141463  //                    bne x8 x17 0x8      | taken
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BNE\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "00841463"

    # execute, branch should NOT be taken !
    await RisingEdge(dut.clk) # bne x8 x8 0x8
    assert binary_to_hex(dut.core.instruction.value) == "01141463"

    # execute, branch SHOULD be taken !
    await RisingEdge(dut.clk) # bne x8 x17 0x8
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    ##################
    # 01145463  //BGE TEST START :    bge x8 x17 0x8      | not taken
    # 00845463  //                    bge x8 x8 0x8       | taken
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BGE\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "01145463"

    # execute, branch should NOT be taken !
    await RisingEdge(dut.clk) # bge x8 x17 0x8 
    assert binary_to_hex(dut.core.instruction.value) == "00845463"

    # execute, branch SHOULD be taken !
    await RisingEdge(dut.clk) # bge x8 x8 0x8 
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    ##################
    # 01146463  //BLTU TEST START :   bltu x8 x17 0x8     | not taken
    # 0088E463  //                    bltu x17 x8 0x8     | taken
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BLTU\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "01146463"

    # execute, branch should NOT be taken !
    await RisingEdge(dut.clk) # bltu x8 x17 0x8
    assert binary_to_hex(dut.core.instruction.value) == "0088E463"

    # execute, branch SHOULD be taken !
    await RisingEdge(dut.clk) # bltu x17 x8 0x8
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    
    ##################
    # 0088F463  //BGEU TEST START :   bgeu x17 x8 0x8     | not taken
    # 01147463  //                    bgeu x8 x17 0x8     | taken
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)
    ##################
    print("\n\nTESTING BGEU\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "0088F463"

    # execute, branch should NOT be taken !
    await RisingEdge(dut.clk) # bgeu x17 x8 0x8
    assert binary_to_hex(dut.core.instruction.value) == "01147463"

    # execute, branch SHOULD be taken !
    await RisingEdge(dut.clk) # bgeu x8 x17 0x8 
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    # We verify x8 value was not altered by addi instruction, because it was never meant tyo be executed (sad)
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"

    ##################
    # 00000397  //JALR TEST START :   auipc x7 0x0        | x7 <= 00000110                PC = 0x110 
    # 01438393  //                    addi x7 x7 0x14     | x7 <= 00000124                PC = 0x114
    # FFC380E7  //                    jalr x1  -4(x7)     | x1 <= 00000118, go @PC 0x120  PC = 0x118
    # 00C00413  //                    addi x8 x0 0xC      | NEVER EXECUTED (check value)  PC = 0x11C
    ##################
    print("\n\nTESTING JALR\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "00000397"
    assert binary_to_hex(dut.core.pc.value) == "00000110"

    await RisingEdge(dut.clk) # auipc x7 0x00 
    await RisingEdge(dut.clk) # addi x7 x7 0x10 
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00000124"

    await RisingEdge(dut.clk) # jalr x1  -4(x7)
    assert binary_to_hex(dut.core.regfile.registers[1].value) == "0000011C"
    assert not binary_to_hex(dut.core.instruction.value) == "00C00413"
    assert binary_to_hex(dut.core.regfile.registers[8].value) == "FFFFFFEE"
    assert binary_to_hex(dut.core.pc.value) == "00000120"

    #################
    # 008020A3  //SB TEST START :     sw x8 0x1(x0)       | NO WRITE ! (mis-aligned !)
    # 00818323  //                    sb x8 0x6(x3)       | mem @ 0x4 <= 00EE0000 
    ##################
    print("\n\nTESTING SB\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "008020A3"

    await RisingEdge(dut.clk) # sw x8 0x1(x0)
    # address is 1 because 0x6 is word @ address 4 and the test bench gets data by word
    #assert binary_to_hex(dut.core.data_cache.cache_data[1].value) == "00000000" 
    assert read_cache(dut.core.data_cache.cache_data, 1) == int("00000000",16) # remains UNFAZED
    assert binary_to_hex(dut.core.instruction.value) == "00818323"

    await RisingEdge(dut.clk) # sb x8 0x6(x3)
    assert read_cache(dut.core.data_cache.cache_data, 1) == int("00EE0000",16)

    #################
    # 008010A3  //SH TEST START :     sh x8 1(x0)         | NO WRITE ! (mis-aligned !)
    # 008011A3  //                    sh x8 3(x0)         | NO WRITE ! (mis-aligned !)
    # 00819323  //                    sh x8 6(x3)         | mem @ 0x4 <= FFEE0000   
    ##################
    print("\n\nTESTING SH\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "008010A3"

    await RisingEdge(dut.clk) # sh x8 1(x0)
    # assert binary_to_hex(dut.core.data_cache.cache_data[1].value) == "00EE0000" # remains UNFAZED
    assert read_cache(dut.core.data_cache.cache_data, 1) == int("00EE0000",16) # remains UNFAZED

    await RisingEdge(dut.clk) # sh x8 3(x0)
    assert read_cache(dut.core.data_cache.cache_data, 1) == int("00EE0000",16) # remains UNFAZED

    await RisingEdge(dut.clk) # sh x8 6(x3) 
    assert read_cache(dut.core.data_cache.cache_data, 1) == int("FFEE0000",16) # remains UNFAZED

    #################
    # PARTIAL LOADS
    # 01018393  //LB TEST START :     addi x7 x3 0x10     | x7 <= 00001010 (base address for this test) 
    # FFF3A903  //                    lw x18 -1(x7)       | NO WRITE IN REGISTER ! (x18 last value : FFF8FF00)
    # FFF38903  //                    lb x18 -1(x7)       | x18 <= FFFFFFDE (0xC is DEADBEEF bc sw test)
    # FFD3C983  //LBU TEST START :    lbu x19 -3(x7)      | x19 <= 000000BE
    # FFD39A03  //LH TEST START :     lh x20 -3(x7)       | NO WRITE IN REGISTER ! (x20 last value : 0FFFFEEF)
    # FFA39A03  //                    lh x20 -6(x7)       | x20 <= FFFFDEAD
    # FFD3DA83  //LHU TEST START :    lhu x21 -3(x7)      | NO WRITE IN REGISTER ! (x21 last value : FFFFFFEE)
    # FFA3DA83  //                    lhu x21 -6(x7)      | x21 <= 0000DEAD
    ##################
    print("\n\nTESTING LB\n\n")

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "01018393"

    await RisingEdge(dut.clk) # addi x7 x3 0x10 
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00001010"

    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFF8FF00"
    await RisingEdge(dut.clk) # lw x18 -1(x7)
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFF8FF00"

    await RisingEdge(dut.clk) # lb x18 -1(x7) 
    assert binary_to_hex(dut.core.regfile.registers[18].value) == "FFFFFFDE"

    await RisingEdge(dut.clk) # lbu x19 -3(x7)
    assert binary_to_hex(dut.core.regfile.registers[19].value) == "000000BE"

    await RisingEdge(dut.clk) # lh x20 -3(x7) 
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "0FFFFEEF"

    await RisingEdge(dut.clk) # lh x20 -6(x7)
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "FFFFDEAD"

    await RisingEdge(dut.clk) # lhu x21 -3(x7) 
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "FFFFFFEE"

    await RisingEdge(dut.clk) # lhu x21 -6(x7)
    assert binary_to_hex(dut.core.regfile.registers[21].value) == "0000DEAD"

    #################
    # CACHE WB TEST
    # 20018393  //CACHE WB TEST :     addi x7 x3 0x200    | x7  <= 00001200 (just above 128*4=512B cache size)
    # 0003AA03  //                    lw x20 0x0(x7)      | x20 <= 00000000 + MISS + WRITE BACK + RELOAD !
    ##################

    # Check test's init state
    assert binary_to_hex(dut.core.instruction.value) == "20018393"

    await RisingEdge(dut.clk) # addi x7 x3 0x200
    assert binary_to_hex(dut.core.regfile.registers[7].value) == "00001200"

    assert dut.core.stall.value == 0b1
    assert dut.core.data_cache.next_state.value == SENDING_WRITE_REQ

    # Wait for the cache to retrieve data
    while(dut.core.stall.value == 0b1) :
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk) # lw x20 0x0(x7)
    assert binary_to_hex(dut.core.regfile.registers[20].value) == "00000000"
    assert axi_ram_slave.read(0x00001004, 4) == 0xFFEE0000.to_bytes(4,'little')