import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random


@cocotb.test()
async def alu_test(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await RisingEdge(dut.clk)

    # TEST ADD
    # The alu simpply does full ader for add.
    # The resulting 32 bits can be interpreted as  signed,
    # unsigned, just like the sources. It all depends on 
    # our interpretation.

    dut.alu_control.value = 0
    for _ in range(100):
        # todo
        pass
    
    # TEST DEFAULT ALU

    # TEST ZERO FLAG