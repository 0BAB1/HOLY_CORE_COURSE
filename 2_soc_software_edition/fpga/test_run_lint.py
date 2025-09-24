# HOLY_CORE TESTBECH (FPGA LINT)
#
# This test runs on the top module
# detnied to FPGA use. The goal is to LINT
# this code and check if it can synth before
# throwing it in vivado. We also us this
# TB to run various SoC level tests 
# (e.g. debug) to check if the core reacts as
# expected in this top module.
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
CPU_PERIOD = 10
NUM_CYCLES = 1_000

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    dut.periph_rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    dut.periph_rst_n.value = 1
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())

@cocotb.test()
async def cpu_insrt_test(dut):
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

    # Run a loop for X amount of cycles for
    # behavior tests
    for _ in range(NUM_CYCLES):
        await RisingEdge(dut.clk)