# HOLY_CORE TESTBECH
#
# Uses a pre-made hardcoded HEX program.
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
import numpy as np
import os

# WARNING : Passing test on async cloks does not mean CDC timing sync is met !
AXI_PERIOD = 10
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
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    await RisingEdge(dut.aclk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
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

    SIZE = 2**15
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    await cpu_reset(dut)

    program_hex = os.environ["IHEX_PATH"]
    axi_ram_slave.write(0x0, int("FFFFF3B7", 16).to_bytes(4,'little'))
    axi_ram_slave.write(0x4, int("7C101073", 16).to_bytes(4,'little'))
    axi_ram_slave.write(0x8, int("7C239073", 16).to_bytes(4,'little'))
    await init_memory(axi_ram_slave, program_hex, 0x000C)

    if "test_imemory.hex" in program_hex:
        # If we are loading custom program, also manually load custom init .data
        await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)

  
    ############################################
    # TEST BENCH
    ############################################

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)

    # Verify that we execute our non-cachable setup
    assert dut.core.instruction.value == 0xFFFFF3B7
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C101073
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C239073
    await RisingEdge(dut.clk)

    # actual test program execution
    for _ in range(10_000):
        await RisingEdge(dut.clk)
        if dut.core.instruction.value.integer == 0x0000006F:
            break

    # At the end of the test, dump everythin in a file
    dump_dir = os.path.dirname(program_hex)
    dump_path = os.path.join(dump_dir, "DUT-holy_core.signature")


    with open(dump_path, 'w') as sig_file:
        sig_file.write("6f5ca309\n")  # Start marker

        consecutive_zeros = 0
        dumping = False
        collected_lines = []

        for addr in range(0x0, 0x8000, 4):
            word_bytes = axi_lite_ram_slave.read(addr, 4)
            word = int.from_bytes(word_bytes, byteorder='little')
            hex_str = "{:08x}".format(word)  # always lowercase

            if not dumping:
                if word != 0 and word != 1: # todo, make this better...
                    dumping = True
                    collected_lines.append(hex_str)
                    consecutive_zeros = 0 if word != 0 else 1
            else:
                collected_lines.append(hex_str)
                if word == 0:
                    consecutive_zeros += 1
                    if consecutive_zeros >= 10:
                        # Remove the last 10 zero lines
                        collected_lines = collected_lines[:-10]
                        break
                else:
                    consecutive_zeros = 0

        # Write the actual signature
        for line in collected_lines:
            sig_file.write(line + "\n")

        # Write the end markers
        sig_file.write("6f5ca309\n")
        sig_file.write("00000000\n")

        print("TEST DONE ON:", dump_path)