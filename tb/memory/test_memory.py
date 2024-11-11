import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def memory_data_test(dut):
    # INIT MEMORY
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.write_enable.value = 0
    dut.address.value = 0
    dut.write_data.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Assert all is 0 after reset
    for address in range(dut.WORDS.value):
        dut.address.value = address
        await Timer(1, units="ns")
        # just 32 zeroes, you can also use int()
        assert dut.read_data.value == "00000000000000000000000000000000"
        
    # Test: Write and read back data
    test_data = [
        (0, 0xDEADBEEF),
        (4, 0xCAFEBABE),
        (8, 0x12345678),
        (12, 0xA5A5A5A5)
    ]

    # For the first tests, we deal with word operations
    dut.byte_enable.value = 0b1111

    # ======================
    # BASIC WORD WRITE TEST
    # ======================

    for address, data in test_data:
        dut.address.value = address
        dut.write_data.value = data

        # write
        dut.write_enable.value = 1
        await RisingEdge(dut.clk)
        dut.write_enable.value = 0
        await RisingEdge(dut.clk)

        # Vvrify by reading back
        dut.address.value = address
        await RisingEdge(dut.clk)
        assert dut.read_data.value == data, f"Error at address {address}: expected {hex(data)}, got {hex(dut.read_data.value)}"

    # ==============
    # WRITE TEST #2
    # ==============

    for i in range(40,4):
        dut.address.value = i
        dut.write_data.value = i
        dut.write_enable.value = 1
        await RisingEdge(dut.clk)

    # ==============
    # NO WRITE TEST
    # ==============

    dut.write_enable.value = 0
    for i in range(40,4):
        dut.address.value = i
        await RisingEdge(dut.clk)
        expected_value = i
        assert dut.read_data.value == expected_value, f"Expected {expected_value}, got {dut.read_data.value} at address {i}"