import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

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

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

@cocotb.test()
async def cpu_insrt_test(dut):
    """Runs a lw datapath test"""
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await RisingEdge(dut.clk)
    await cpu_reset(dut)

    ##################
    # LOAD WORD TEST 
    # lw x18 0x8(x0)
    ##################
    print("\n\nTESTING LW\n\n")

    # The first instruction for the test in imem.hex load the data from
    # dmem @ adress 0x00000008 that happens to be 0xDEADBEEF into register x18

    # Wait a clock cycle for the instruction to execute
    await RisingEdge(dut.clk) # lw x18 0x8(x0)

    # Check the value of reg x18
    assert binary_to_hex(dut.regfile.registers[18].value) == "DEADBEEF", f"expected DEADBEEF but got {binary_to_hex(dut.regfile.registers[18].value)} @ pc {binary_to_hex(dut.pc.value)}"

    ##################
    # STORE WORD TEST 
    # sw x18 0xC(x0)
    ##################
    print("\n\nTESTING SW\n\n")
    test_address = int(0xC / 4) #mem is byte adressed but is made out of words in the eyes of the software
    # The second instruction for the test in imem.hex stores the data from
    # x18 (that happens to be 0xDEADBEEF from the previous LW test) @ adress 0x0000000C 

    # First, let's check the inital value
    assert binary_to_hex(dut.data_memory.mem[test_address].value) == "F2F2F2F2", f"expected F2F2F2F2 but got {binary_to_hex(dut.data_memory.mem[test_address].value)} @ pc {binary_to_hex(dut.pc.value)}"

    # Wait a clock cycle for the instruction to execute
    await RisingEdge(dut.clk) # sw x18 0xC(x0)
    # Check the value of mem[0xC]
    assert binary_to_hex(dut.data_memory.mem[test_address].value) == "DEADBEEF", f"expected DEADBEEF but got {binary_to_hex(dut.data_memory.mem[test_address].value)} @ pc {binary_to_hex(dut.pc.value)}"

    ##################
    # ADD TEST
    # lw x19 0x10(x0) (this memory spot contains 0x00000AAA)
    # add x20 x18 x19
    ##################
    print("\n\nTESTING ADD\n\n")

    # Expected result of x18 + x19
    expected_result = (0xDEADBEEF + 0x00000AAA) & 0xFFFFFFFF
    await RisingEdge(dut.clk) # lw x19 0x10(x0)
    assert binary_to_hex(dut.regfile.registers[19].value) == "00000AAA"
    await RisingEdge(dut.clk) # add x20 x18 x19
    assert binary_to_hex(dut.regfile.registers[20].value) == hex(expected_result)[2:].upper(),  f"expected {hex(expected_result)[2:]}  but got {binary_to_hex(dut.regfile.registers[20].value)} @ pc {binary_to_hex(dut.pc.value)}"

    ##################
    # AND TEST
    # and x21 x18 x20 (result shall be 0xDEAD8889)
    ##################
    print("\n\nTESTING AND\n\n")

    # Use last expected result, as this instr uses last op result register
    expected_result = expected_result & 0xDEADBEEF
    await RisingEdge(dut.clk) # and x21 x18 x20
    assert binary_to_hex(dut.regfile.registers[21].value) == "DEAD8889"

    ##################
    # OR TEST
    # For this one, I decider to load some more value to change the "0xdead.... theme" ;)
    # (Value pre-computed in python)
    # lw x5 0x14(x0) | x5  <= 125F552D
    # lw x6 0x18(x0) | x6  <= 7F4FD46A
    # or x7 x5 x6    | x7  <= 7F5FD56F
    ##################
    print("\n\nTESTING OR\n\n")

    await RisingEdge(dut.clk) # lw x5 0x14(x0) | x5  <= 125F552D
    assert binary_to_hex(dut.regfile.registers[5].value) == "125F552D"
    await RisingEdge(dut.clk) # lw x6 0x18(x0) | x6  <= 7F4FD46A
    assert binary_to_hex(dut.regfile.registers[6].value) == "7F4FD46A"
    await RisingEdge(dut.clk) # or x7 x5 x6    | x7  <= 7F5FD56F
    assert binary_to_hex(dut.regfile.registers[7].value) == "7F5FD56F"

    ##################
    # BEQ TEST
    # (Value pre-computed in python)
    # 00730663  //BEQ TEST START :    beq x6 x7 0xC       | #1 SHOULD NOT BRANCH
    # 00802B03  //                    lw x22 0x8(x0)      | x22 <= DEADBEEF
    # 01690863  //                    beq x18 x22 0x10    | #2 SHOULD BRANCH (+ offset)
    # 00000013  //                    nop                 | NEVER EXECUTED
    # 00000013  //                    nop                 | NEVER EXECUTED
    # 00000663  //                    beq x0 x0 0xC       | #4 SHOULD BRANCH (avoid loop)
    # 00002B03  //                    lw x22 0x0(x0)      | x22 <= AEAEAEAE
    # FF6B0CE3  //                    beq x22 x22 -0x8    | #3 SHOULD BRANCH (-offset)
    # 00000013  //                    nop                 | FINAL NOP
    ##################
    print("\n\nTESTING BEQ\n\n")

    assert binary_to_hex(dut.instruction.value) == "00730663"

    await RisingEdge(dut.clk) # beq x6 x7 0xC NOT TAKEN
    # Check if the current instruction is the one we expected
    assert binary_to_hex(dut.instruction.value) == "00802B03"

    await RisingEdge(dut.clk) # lw x22 0x8(x0)
    assert binary_to_hex(dut.regfile.registers[22].value) == "DEADBEEF"

    await RisingEdge(dut.clk) # beq x18 x22 0x10 TAKEN
    # Check if the current instruction is the one we expected
    assert binary_to_hex(dut.instruction.value) == "00002B03"

    await RisingEdge(dut.clk) # lw x22 0x0(x0)
    assert binary_to_hex(dut.regfile.registers[22].value) == "AEAEAEAE"

    await RisingEdge(dut.clk) # beq x22 x22 -0x8 TAKEN
    # Check if the current instruction is the one we expected
    assert binary_to_hex(dut.instruction.value) == "00000663"

    await RisingEdge(dut.clk) # beq x0 x0 0xC TAKEN
    # Check if the current instruction is the one we expected
    assert binary_to_hex(dut.instruction.value) == "00000013"
    await RisingEdge(dut.clk) # NOP

    ##################
    # 00C000EF  //JAL TEST START :    jal x1 0xC          | #1 jump @PC+0xC | PC 0x44
    # 00000013  //                    nop                 | NEVER EXECUTED  | PC 0x48
    # 00C000EF  //                    jal x1 0xC          | #2 jump @PC-0x4 | PC 0x4C   
    # FFDFF0EF  //                    jal x1 -4           | #2 jump @PC-0x4 | PC 0x50
    # 00000013  //                    nop                 | NEVER EXECUTED  | PC 0x54
    # 00C02383  //                    lw x7 0xC(x0)       | x7 <= DEADBEEF  | PC 0x58
    ##################
    print("\n\nTESTING JAL\n\n")

    # Check test's init state
    assert binary_to_hex(dut.instruction.value) == "00C000EF"
    assert binary_to_hex(dut.pc.value) == "00000044"

    await RisingEdge(dut.clk) # jal x1 0xC
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.instruction.value) == "FFDFF0EF"
    assert binary_to_hex(dut.pc.value) == "00000050"
    assert binary_to_hex(dut.regfile.registers[1].value) == "00000048" # stored old pc + 4

    await RisingEdge(dut.clk) # jal x1 -4
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.instruction.value) == "00C000EF"
    assert binary_to_hex(dut.pc.value) == "0000004C"
    assert binary_to_hex(dut.regfile.registers[1].value) == "00000054" # stored old pc + 4

    await RisingEdge(dut.clk) # jal x1 0xC
    # Check new state & ra (x1) register value
    assert binary_to_hex(dut.instruction.value) == "00C02383"
    assert binary_to_hex(dut.pc.value) == "00000058"
    assert binary_to_hex(dut.regfile.registers[1].value) == "00000050" # stored old pc + 4

    await RisingEdge(dut.clk) # lw x7 0xC(x0)
    assert binary_to_hex(dut.regfile.registers[7].value) == "DEADBEEF"
    
    ##################
    # ADDI TEST
    # 1AB38D13  //                    addi x26 x7 0x1AB   | x26 <= DEADC09A
    # F2130C93  //                    addi x25 x6 0xF21   | x25 <= DEADBE10
    ##################
    print("\n\nTESTING ADDI\n\n")

    # Check test's init state
    assert binary_to_hex(dut.instruction.value) == "1AB38D13"
    assert not binary_to_hex(dut.regfile.registers[26].value) == "DEADC09A"

    await RisingEdge(dut.clk) # addi x26 x7 0x1AB
    assert binary_to_hex(dut.instruction.value) == "F2130C93"
    assert binary_to_hex(dut.regfile.registers[26].value) == "DEADC09A"

    await RisingEdge(dut.clk) # addi x25 x6 0xF21
    assert binary_to_hex(dut.regfile.registers[25].value) == "7F4FD38B"