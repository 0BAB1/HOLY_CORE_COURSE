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

    # ----------------------------------
    # flush cache is 0 on start
    assert dut.flush_cache.value == 0x00000000

    # ----------------------------------
    # test simple write
    dut.write_enable.value = 1
    dut.write_data.value = 0xDEADBEEF
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(5, units="ns")
    assert dut.flush_cache.value == 0xDEADBEEF
    assert dut.read_data.value == 0xDEADBEEF

    # ----------------------------------
    # nothing gets written if we flag is low
    dut.write_enable.value = 0b0
    dut.write_data.value = 0x12345678
    await RisingEdge(dut.clk)
    assert dut.flush_cache.value == 0xDEADBEEF

    # ----------------------------------
    # randomized test
    dut.write_enable.value = 0b1
    for _ in range(1000):
        init_csr_value = dut.flush_cache.value
        wd = random.randint(0, 0xFFFFFFFF)
        f3 = random.randint(0b000, 0b111)
        dut.write_data.value = wd
        dut.f3.value = f3

        await RisingEdge(dut.clk)
        await Timer(5, units="ns")
        if f3 == 0b000 or f3 == 0b100:
            assert dut.read_data == 0
        elif f3 == 0b001 or f3 == 0b101:
            assert (
                dut.read_data
                == wd
            )
        elif f3 == 0b010 or f3 == 0b110:
            assert (
                dut.read_data
                == (init_csr_value | wd)
            )
        elif f3 == 0b011 or f3 == 0b111:
            assert (
                dut.read_data
                == (init_csr_value & (~wd & 0xFFFFFFFF)) #we mask wd to 32 bits
            )
    
    # ----------------------------------
    # test reset, first write sample data
    dut.write_enable.value = 1
    dut.write_data.value = 0xDEADBEEF
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)

    # then we release reset and check for 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    assert dut.flush_cache.value == 0x00000000

    # ======================================
    # test registers behavior
    # ======================================

    # ----------------------------------
    # FLUSH CACHE CSR BEHAVIOR :
    # If this CSR's LSB is asserted, the module ouputs 1 on "flush"
    # order output for 1 cycle. This is automatically deasserted after a clock cycle

    # flush_cache_flag should be 0
    assert dut.flush_cache_flag.value == 0b0

    # Then we set all bits to 1 excpt LSB, should still be 0
    dut.write_enable.value = 1
    dut.write_data.value = 0xFFFFFFFE
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    assert dut.flush_cache_flag.value == 0b0
    assert dut.flush_cache.value == 0xFFFFFFFE

    # Then we write 1, should output 1
    dut.write_enable.value = 1
    dut.write_data.value = 0x00000001
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    assert dut.flush_cache_flag.value == 0b1
    assert dut.flush_cache.value == 0x00000001

    # should go back to 0 after a single cycle
