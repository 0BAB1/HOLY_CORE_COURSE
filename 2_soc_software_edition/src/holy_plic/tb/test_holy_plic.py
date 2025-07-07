# PLIC TESTBECH
#
# BRH 7/25

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

# AXI LITE SLAVE STATES
SLAVE_IDLE                  = 0b00
LITE_RECEIVING_WRITE_DATA   = 0b01
LITE_SENDING_WRITE_RES      = 0b10
LITE_SENDING_READ_DATA      = 0b11

@cocotb.test()
async def main_test(dut):
    """
        In this test, we'll check *basic* compliance on the
        Privileged specs for a PLIC. By "basic" is implied that
        some basic functionalities may not be supported yet.
        Don't hate though, it's just to make it literally as
        simple as possible.
    """

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.rst_n, reset_active_level=False)

    await Timer(1, units="ns")
    assert True

