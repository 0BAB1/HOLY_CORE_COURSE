# HOLY_CORE TESTBECH
#
# Based on a fixed test prgram to test
# The basics (very) quickly. This test
# Does not ensure compliance but rather
# serve as a quick reference to know if
# the design compiles and if a change
# broke the basic CPU behavior. RV
# standards compliance is ensured by
# another tesbench meant to work with
# riscof signature system.
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
AXI_PERIOD = 10
CPU_PERIOD = 10

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    dut.aresetn.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.aresetn.value = 1
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())

@cocotb.test()
async def cpu_insrt_test(dut):

    print("hi")
    assert True

    await inst_clocks(dut)

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=1028, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=1028, reset_active_level=False)

    await cpu_reset(dut)

    axi_ram_slave.write(0,int.to_bytes(0x000000ef, 4, byteorder='little'))
    axi_lite_ram_slave.write(0,int.to_bytes(0x000000ef, 4, byteorder='little'))

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)
    
    await RisingEdge(dut.clk)


    dut.tb_debug_req.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    dut.tb_debug_req.value = 0

    for _ in range(1000):
        await RisingEdge(dut.clk)