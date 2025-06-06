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

def format_gpr(idx):
    if idx < 10:
        return f"x{idx} "
    else:
        return f"x{idx}"

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
            print(f'RUNNING INIT @{hex(addr)} => {instruction}')
            axi_ram.hexdump(addr,4)
            addr_offset += 4

@cocotb.test()
async def cpu_insrt_test(dut):

    ############################################
    # TEST SYMBOLS GETTER
    ############################################

    # GET SIGNATURES SYMBOLS ADDRS FOR ENV PASSED VARS
    # passed sybols from plugin :
    # symbols_list = ['begin_signature', 'end_signature', 'tohost', 'fromhost']

    try :
        begin_signature = int(os.environ["begin_signature"],16)
        end_signature = int(os.environ["end_signature"],16)
        write_tohost = int(os.environ["write_tohost"],16)
    except KeyError:
        print("NO SYBOLS PAST, SKIPPING SIGNATURE WRITE, error may get raised")
        raise KeyError("NO SYBOLS PAST, SKIPPING SIGNATURE WRITE")
    
    # Clear the log file before simulation starts
    with open("dut.log", "w"):
        pass  # Just open in write mode to truncate

    await inst_clocks(dut)

    SIZE = 2**32
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    await cpu_reset(dut)

    program_hex = os.environ["IHEX_PATH"]
    # This unlogged sequence set ups the cache to output via AXI LITE only
    # to avoid caching side effects. (custom csrs config)
    axi_ram_slave.write(0x0, int("FFFFF3B7", 16).to_bytes(4,'little')) # li
    axi_ram_slave.write(0x4, int("7C101073", 16).to_bytes(4,'little')) # cssrw
    axi_ram_slave.write(0x8, int("7C239073", 16).to_bytes(4,'little')) # cssrw
    # jump to 0x8000_0000 to comply with spike logs format
    axi_ram_slave.write(0xC, int("800000B7", 16).to_bytes(4,'little')) # lui   x1, 0x80000
    axi_ram_slave.write(0x10, int("00008067", 16).to_bytes(4,'little')) # jalr  x0, 0(x1)
    await init_memory(axi_ram_slave, program_hex, 0x80000000)
    await init_memory(axi_lite_ram_slave, program_hex, 0x80000000)

    print(f"begin_signature = {hex(begin_signature)}")
    print(f"end_signature = {hex(end_signature)}")
    print(f"write_tohost = {hex(write_tohost)}")
  
    ############################################
    # TEST BENCH
    ############################################

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)

    # Verify that we execute our non-cachable setup, this will not get logged
    assert dut.core.instruction.value == 0xFFFFF3B7
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C101073
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C239073
    
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x800000B7
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x00008067

    # check that we're about to jump to 0x8000_0000
    await Timer(1, units="ps")
    assert dut.core.pc.value == 0x8000_0000

    # actual test program execution
    while not dut.core.pc.value.integer >= write_tohost:
        await Timer(1, units="ps") # let signals info propagate in sim
        print(f'PC : {hex(dut.core.pc.value.integer)} <= {hex(write_tohost)}')

        ##########################################################
        # SPIKE LIKE LOGS (inspired by jeras' work, link below)
        # https://github.com/jeras/rp32/blob/master/hdl/tbn/riscof/r5p_degu_trace_logger.sv
        ##########################################################

        # if we're about to execute the instruction, we can log.
        if dut.core.stall.value == 0:
            # --- Initialize logging strings
            str_ifu = ""
            str_gpr = ""
            str_lsu = ""

            # --- GPR write-back logging ---
            if dut.core.reg_write.value and dut.core.wb_valid.value:
                if dut.core.dest_reg.value.integer != 0:  # ignore x0
                    reg_id = dut.core.dest_reg.value.integer
                    reg_val = dut.core.write_back_data.value.integer
                    str_gpr = f" {format_gpr(reg_id)} 0x{reg_val:08x}"
                else:
                    str_gpr = ""
            else:
                str_gpr = ""

            # --- LSU memory logging ---
            if dut.core.mem_write_enable.value:  # memory store
                # address comes from alu_result directly in holy_core
                addr = dut.core.alu_result.value.integer
                data = dut.core.mem_write_data.value.integer
                str_lsu = f" mem 0x{addr:08x} 0x{data:08x}"
            elif dut.core.mem_read_enable.value:  # memory load
                addr = dut.core.alu_result.value.integer
                data = dut.core.mem_read.value.integer
                str_lsu = f" 0x{addr:08x} (0x{data:08x})"

            # --- Instruction fetch logging ---
            pc = dut.core.pc.value.integer
            instr = dut.core.instruction.value.integer
            instr_size = 4  # instruction are always 4 bytes for now...

            if instr_size == 4:
                str_ifu = f" 0x{pc:08x} (0x{instr:08x})"
            else:
                # not used but its here, we nere know ;)
                str_ifu = f" 0x{pc:08x} (0x{instr & 0xFFFF:04x})"

            # --- Write final combined log line ---
            with open("dut.log", "a") as fd:
                fd.write(f"core   0: 3{str_ifu}{str_gpr}{str_lsu}\n")
            
        await RisingEdge(dut.clk)

    # =========================
    # SIGNATURE DUMP
    # =========================

    dump_dir = os.path.dirname(program_hex)
    dump_path = os.path.join(dump_dir, "DUT-holy_core.signature")

    with open(dump_path, 'w') as sig_file:
        consecutive_zeros = 0
        dumping = False
        collected_lines = []

        for addr in range(begin_signature, end_signature, 4):
            print(f'dumping addr {hex(addr)} in sig file')
            word_bytes = axi_lite_ram_slave.read(addr, 4)
            word = int.from_bytes(word_bytes, byteorder='little')
            hex_str = "{:08x}".format(word)  # always lowercase
            
            collected_lines.append(hex_str)

        # Write the actual signature
        for line in collected_lines:
            sig_file.write(line + "\n")