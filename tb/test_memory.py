import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Reset coroutine, called for each tets
async def reset_memory(design):
    # Initialize inputs
    design.rst_n <= 0
    design.write_enable <= 0
    design.address <= 0
    design.write_data <= 0

    # Apply reset
    await Timer(20, units="ns")   # Wait 20 ns for reset to settle
    design.rst_n <= 1                # De-assert reset
    await RisingEdge(design.clk)     # Wait for a clock edge after reset

@cocotb.test()
async def memory_reset_test(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    await reset_memory(dut)

    # Test: Check that memory is cleared after reset
    for addr in range(dut.WORDS.value):
        dut.address <= addr
        await RisingEdge(dut.clk)
        assert dut.read_data.value == 0, f"Memory at address {addr} is not zero after reset"

@cocotb.test()
async def memory_data_test(dut):
    # Test: Write and read back data
    test_data = [
        (0, 0xDEADBEEF),
        (1, 0xCAFEBABE),
        (2, 0x12345678),
        (3, 0xA5A5A5A5)
    ]

    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    await reset_memory(dut)

    for address, data in test_data:
        # Write data to memory
        dut.address <= address
        dut.write_data <= data
        dut.write_enable <= 1
        await RisingEdge(dut.clk)

        # Disable write after one cycle
        dut.write_enable <= 0
        await RisingEdge(dut.clk)

        # Verify the write by reading back
        dut.address <= address
        await RisingEdge(dut.clk)
        assert dut.read_data.value == data, f"Readback error at address {address}: expected {hex(data)}, got {hex(dut.read_data.value)}"

    # Test: Write to multiple addresses, then read back
    for i in range(10):
        dut.address <= i
        dut.write_data <= i + 100
        dut.write_enable <= 1
        await RisingEdge(dut.clk)

    # Disable write, then read back values to check
    dut.write_enable <= 0
    for i in range(10):
        dut.address <= i
        await RisingEdge(dut.clk)
        expected_value = i + 100
        assert dut.read_data.value == expected_value, f"Expected {expected_value}, got {dut.read_data.value} at address {i}"