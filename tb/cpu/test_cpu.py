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
    # lw x19 0x10(x0) (tis memory spot contains 0x00000AAA)
    # add x20 x18 x19
    ##################

    # Expected result of x18 + x19
    expected_result = (0xDEADBEEF + 0x00000AAA) & 0xFFFFFFFF
    await RisingEdge(dut.clk) # lw x19 0x10(x0)
    assert binary_to_hex(dut.regfile.registers[19].value) == "00000AAA"
    await RisingEdge(dut.clk) # add x20 x18 x19
    assert binary_to_hex(dut.regfile.registers[20].value) == hex(expected_result)[2:].upper(),  f"expected {hex(expected_result)[2:]}  but got {binary_to_hex(dut.regfile.registers[20].value)} @ pc {binary_to_hex(dut.pc.value)}"