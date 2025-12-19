# HOLY_CORE *Internal* SoC TESTBECH (FPGA + CHECKS)
#
# This test runs on the top module
# detnied to FPGA use. The goal is to LINT
# this code and check how the internal SoC
# bhaves and interacts with externals before
# throwing it in vivado. We also us this
# TB to freely run various SoC level tests 
# to check if the core reacts as expected
# in the internal SoC.
#
# Because the DUT is the atual FPGA top module,
# ROM will be at address 0. To modify said ROM,
# instructions are in this ./ROM/readme.md folder.
#
# Because this is a cocotb testbench for the
# internals of the SoC, there is no RAM and
# we use cocotb's simulated AXI RAM. It is initally
# loaded with the program in ./test_program.hex
# simply drop in any hex you want. Note that you
# can grab .hex dumps in the <root>/example program
# after compilation, allowing to simulate whatever
# you want External read/write, that would usually
# be destined for external controlers like UART or GPIO
# will be done on a blank RAM slave as well.
#
# BRH 11/25

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
from cocotb.handle import Force, Release

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
CPU_PERIOD = 10
NUM_CYCLES = 1_000_000

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

@cocotb.coroutine
async def init_memory(axi_ram : AxiRam, hexfile, base_addr):
    addr_offset = 0
    with open(hexfile, "r") as file:
        for raw_instruction in file :
            addr = addr_offset + base_addr
            str_instruction = raw_instruction.split("/")[0].strip()
            instruction = int(str_instruction, 16).to_bytes(4,'little')
            axi_ram.write(addr, instruction)
            axi_ram.hexdump(addr,4)
            addr_offset += 4

@cocotb.test()
async def cpu_insrt_test(dut):
    await inst_clocks(dut)

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=0x90000000, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=0x90000000, reset_active_level=False)

    await cpu_reset(dut)

    # Init the memories with the program data. Both are sceptible to be queried so we init both.
    # On a real SoC, a single memory will be able to answer bot axi and axi lite interfaces
    hex_path = "./cache_stress_test.hex"
    await init_memory(axi_ram_slave, hex_path, 0x80000000)
    await init_memory(axi_lite_ram_slave, hex_path, 0x80000000)

    num_cycles = 0

    while dut.core.exception.value == 0 and (dut.core.instruction.value != 0xffdff06f):
        await RisingEdge(dut.clk)
        num_cycles += 1

        if num_cycles % 5000 == 0:
            print("===============")
            print("cycles : ", num_cycles)
            print("pc : ", dut.core.pc.value)

    print("OVER!")
    await ClockCycles(dut.clk, 500)
