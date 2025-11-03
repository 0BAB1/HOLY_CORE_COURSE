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
import random
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
import numpy as np

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

def binary_to_hex(bin_str):
    # Convert binary string to hexadecimal
    hex_str = hex(int(str(bin_str), 2))[2:]
    hex_str = hex_str.zfill(8)
    return hex_str.upper()

def hex_to_bin(hex_str):
    # Convert hex str to bin
    bin_str = bin(int(str(hex_str), 16))[2:]
    bin_str = bin_str.zfill(32)
    return bin_str.upper()

def read_cache(cache_data, line) :
    """To read cache_data, because the packed array makes it an array of bits..."""
    l = 127 - line
    return (int(str(cache_data.value[32*l:(32*l)+31]),2))

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
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


    ##################

    pc_values = []
    instr_values = []
    R1_values = []
    R2_values = []
    imm_values = []
    mem_values = []
    wb_values = []
    OP_type = []

    for i in range(1000):
        await NextInstr(dut)
        pc_values.append(int(dut.core.pc.value))
        instr_values.append(int(dut.core.instruction.value))
        R1_values.append(int(dut.core.read_reg1.value))
        R2_values.append(int(dut.core.read_reg2.value))
        imm_values.append(int(dut.core.immediate.value))
        mem_values.append(int(dut.core.mem_read.value))
        wb_values.append(int(dut.core.write_back_signal.value))
        OP_type.append(0)

    import pickle

    data = {
        "pc": pc_values,
        "instr": instr_values,
        "R1": R1_values,
        "R2": R2_values,
        "imm": imm_values,
        "mem": mem_values,
        "wb": wb_values,
        "op_type": OP_type,
    }

    with open("trace_data.pkl", "wb") as f:
        pickle.dump(data, f)