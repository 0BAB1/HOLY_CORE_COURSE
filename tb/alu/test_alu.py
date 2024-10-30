import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


@cocotb.test()
async def alu_test(dut):
    await Timer(1, units="ns")

    # TEST ADD
    # The alu simpply does a biwise add.
    # The resulting 32 bits can be interpreted as signed,
    # unsigned, just like the sources. It all depends on 
    # our interpretation.

    dut.alu_control.value = 0b000
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2
        # We mask expected to not take account of overflows
        expected = (src1 + src2) & 0xFFFFFFFF
        # Await 1 ns for the infos to propagate
        await Timer(1, units="ns")
        assert int(dut.alu_result.value) == expected

    # TEST DEFAULT ALU
    await Timer(1, units="ns")
    dut.alu_control.value = 0b111
    src1 = random.randint(0,0xFFFFFFFF)
    src2 = random.randint(0,0xFFFFFFFF)
    dut.src1.value = src1
    dut.src2.value = src2
    expected = 0
    # Await 1 ns for the infos to propagate
    await Timer(1, units="ns")
    assert int(dut.alu_result.value) == expected

    # TEST ZERO FLAG
    assert int(dut.zero.value) == 1
