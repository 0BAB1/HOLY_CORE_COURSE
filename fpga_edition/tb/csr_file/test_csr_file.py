# REGFILE TESTBECH
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import numpy as np

@cocotb.test()
async def test_csr_file(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # flush cache is 0 on start
    assert dut.flush_cache.value == 0x00000000

    # test simple write
    dut.write_enable.value = 1
    dut.write_data.value = 0xDEADBEEF
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(5, units="ns")
    assert dut.flush_cache.value == 0xDEADBEEF
    assert dut.read_data.value == 0xDEADBEEF

    # nothing gets writtn if we id low
    dut.write_enable.value = 0b0
    dut.write_data.value = 0x12345678
    await RisingEdge(dut.clk)
    assert dut.flush_cache.value == 0xDEADBEEF

    # randomized test
    dut.write_enable.value = 0b1
    for _ in range(100):
        wd = random.randint(0, 0xFFFFFFFF)
        f3 = random.randint(0b000, 0b111)
        dut.write_data.value = wd
        dut.f3.value = f3

        await RisingEdge(dut.clk)
        await Timer(5, units="ns")
        if f3 == 0b000 or f3 == 100:
            assert dut.read_data == 0
