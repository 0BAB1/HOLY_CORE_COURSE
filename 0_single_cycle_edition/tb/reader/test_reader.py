# READER TESTBECH
#
# BRH 10/24

import cocotb
from cocotb.triggers import Timer
import random

# 100 random test per mask

@cocotb.test()
async def reader_lw_test(dut):
    # LW TEST CASE
    dut.f3.value = 0b010
    await Timer(1, units="ns")
    dut.be_mask.value = 0b1111
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == mem_data 


@cocotb.test()
async def reader_invalid_test(dut):
    dut.f3.value = 0b001
    dut.mem_data.value = random.randint(0,0xFFFFFFFF)
    for i in range(16):
        dut.be_mask.value = i
        await Timer(1, units="ns")
        if i == 0 :
            assert dut.valid.value == 0
        else :
            assert dut.valid.value == 1

@cocotb.test()
async def reader_lh_test(dut):
    # LH TEST CASE
    dut.f3.value = 0b001

    await Timer(1, units="ns")

    dut.be_mask.value = 0b1100
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x7FFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0xFFFF0000) >> 16
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x80000000,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        expected = ((mem_data & 0xFFFF0000) >> 16) - (1 << 16)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0011
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x00007FFF) | 0xAEAE0000 # Add some random AE to check if they are ignored
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x0000FFFF)
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x00008000,0x0000FFFF) | 0xAEAE0000
        dut.mem_data.value = mem_data
        expected = (mem_data & 0x0000FFFF) - (1 << 16)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    # LHU TEST CASE
    dut.f3.value = 0b101

    await Timer(1, units="ns")

    dut.be_mask.value = 0b1100
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0xFFFF0000) >> 16
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0011
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x0000FFFF)
        assert dut.valid.value == 1

@cocotb.test()
async def reader_lb_test(dut):
    # LB TEST CASE
    dut.f3.value = 0b000

    await Timer(1, units="ns")

    dut.be_mask.value = 0b1000
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x7FFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0xFF000000) >> 24
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x80000000,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        expected = ((mem_data & 0xFF000000) >> 24) - (1 << 8)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0100
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x007FFFFF) | 0xAE000000
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x00FF0000) >> 16
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x00800000,0x00FFFFFF) | 0xAE000000
        dut.mem_data.value = mem_data
        expected = ((mem_data & 0x00FF0000) >> 16) - (1 << 8)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0010
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x00007FFF) | 0xAEAE0000
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x0000FF00) >> 8
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x00008000,0x0000FFFF) | 0xAEAE0000
        dut.mem_data.value = mem_data
        expected = ((mem_data & 0x0000FF00) >> 8) - (1 << 8)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0001
    await Timer(1, units="ns")
    for _ in range(100):
        # UNSIGNED
        mem_data = random.randint(0,0x0000007F) | 0xAEAEAE00
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x000000FF)
        assert dut.valid.value == 1

        # SIGNED
        mem_data = random.randint(0x00000080,0x000000FF) | 0xAEAEAE00
        dut.mem_data.value = mem_data
        expected = (mem_data & 0x000000FF) - (1 << 8)
        await Timer(1, units="ns")
        assert int(dut.wb_data.value) - (1 << 32) == expected
        assert dut.valid.value == 1

    # LBU TEST CASE
    dut.f3.value = 0b100

    await Timer(1, units="ns")

    dut.be_mask.value = 0b1000
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0xFF000000) >> 24
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0100
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x00FF0000) >> 16
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0010
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x0000FF00) >> 8
        assert dut.valid.value == 1

    dut.be_mask.value = 0b0001
    await Timer(1, units="ns")
    for _ in range(100):
        mem_data = random.randint(0,0xFFFFFFFF)
        dut.mem_data.value = mem_data
        await Timer(1, units="ns")
        assert dut.wb_data.value == (mem_data & 0x000000FF)
        assert dut.valid.value == 1