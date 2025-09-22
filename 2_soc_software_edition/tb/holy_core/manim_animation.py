# HOLY_CORE TESTBECH
#
# Ma,nim animation generator
# around a real simulation of the
# holy core
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
from manim import *
from pyverilog.vparser.parser import parse
import os

SRC_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../src"))

def get_ports_from_verilog(file_path: str, top_module: str):
    ast, _ = parse([file_path])
    ports = []

    # Traverse AST
    for description in ast.description.definitions:
        if description.name == top_module:  # Match the module you care about
            for item in description.portlist.ports:
                decl = item.first  # Port object -> Decl
                if decl is None:
                    continue
                # direction: Input, Output, Inout
                direction = type(decl).__name__.lower()
                # name
                name = decl.name
                # width (if vector)
                msb = getattr(decl.width.msb, 'value', None) if decl.width else None
                lsb = getattr(decl.width.lsb, 'value', None) if decl.width else None
                if msb is not None and lsb is not None:
                    width = abs(int(msb) - int(lsb)) + 1
                else:
                    width = 1

                ports.append((name, direction, width))
    return ports

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
CPU_PERIOD = 10

# CACHE STATES CST
IDLE                        = 0b0000
SENDING_WRITE_REQ           = 0b0001
SENDING_WRITE_DATA          = 0b0010
WAITING_WRITE_RES           = 0b0011
SENDING_READ_REQ            = 0b0100
RECEIVING_READ_DATA         = 0b0101
# LITE states, only for data cache
LITE_SENDING_WRITE_REQ      = 0b0110
LITE_SENDING_WRITE_DATA     = 0b0111
LITE_WAITING_WRITE_RES      = 0b1000
LITE_SENDING_READ_REQ       = 0b1001
LITE_RECEIVING_READ_DATA    = 0b1010

async def NextInstr(dut):
    """Wait for a clock edge, but skip cycles while core is stalled."""
    # Wait until not stalled
    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)
    # Then step one more cycle
    await RisingEdge(dut.clk)

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.aclk, CPU_PERIOD, units="ns").start())
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

module : list[VGroup] = []

@cocotb.test()
async def cpu_insrt_test(dut):

    await inst_clocks(dut)

    # ==============
    # Testbench MEMORY MAP
    # (Not meant to be coherent, just raw testing)
    # ==============
    # 0xFFFF
    # PLIC Module registers
    # 0xF000 
    # ==============
    # 0xEFFF
    # CLINT Module registers
    # 0x3000 
    # ==============
    # 0x2FFF
    # Trap handler code
    # 0x2000
    # ==============
    # 0x1FFF
    # Data
    # 0x1000 (stored in gp : x3)
    # ==============
    # 0x0FFF
    # Instructions
    # 0x0000
    #===============

    SIZE = 2**14

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)

    await cpu_reset(dut)

    print("init axi ram")
    await init_memory(axi_ram_slave, "./test.hex", 0x0000)
    await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)
    print("init axi lite ram")
    await init_memory(axi_lite_ram_slave, "./test.hex", 0x0000)
    await init_memory(axi_lite_ram_slave, "./test_dmemory.hex", 0x1000)

    for handle in dut.core:
        if handle._type == "GPI_MODULE":
            