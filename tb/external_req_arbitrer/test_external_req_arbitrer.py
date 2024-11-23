import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam, AxiMaster
import numpy as np

# https://github.com/alexforencich/cocotbext-axi

# CACHE STATES CST
IDLE                = 0b000
SENDING_WRITE_REQ   = 0b001
SENDING_WRITE_DATA  = 0b010
WAITING_WRITE_RES   = 0b011
SENDING_READ_REQ    = 0b100
RECEIVING_READ_DATA = 0b101

@cocotb.test()
async def main_test(dut):
    PERIOD = 10
    MEM_SIZE = 4096
    cocotb.start_soon(Clock(dut.clk, PERIOD, units="ns").start())

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, reset_active_level=False, size=MEM_SIZE)
    i_cache_master = AxiMaster(AxiBus.from_prefix(dut, "s_axi_instr"), dut.clk, dut.rst_n, reset_active_level=False)
    d_cache_master = AxiMaster(AxiBus.from_prefix(dut, "s_axi_data"), dut.clk, dut.rst_n, reset_active_level=False)

    await RisingEdge(dut.clk)
    # init states to IDLE
    dut.data_cache_state.value = IDLE
    dut.instr_cache_state.value = IDLE
    await Timer(1, units="ns")

    # ========================================
    # SCENARIO 1 : ONLY THE DCACHE WRITES
    # ========================================
    
    dut.data_cache_state.value = SENDING_WRITE_REQ
    await Timer(1, units="ns")
    await d_cache_master.write(0x000, b'test')
    dut.data_cache_state.value = IDLE
    await Timer(1, units="ns")

    assert axi_ram_slave.read(0x000,4) == b'test'

    # ========================================
    # SCENARIO 2 : ONLY THE ICACHE READS
    # ========================================

    dut.instr_cache_state.value = SENDING_READ_REQ
    await Timer(1, units="ns")
    data = await i_cache_master.read(0x000, 4)
    dut.instr_cache_state.value = IDLE
    await Timer(1, units="ns")

    assert data.data == b'test'

    # ========================================
    # SCENARIO 3 : ONLY THE DCACHE READS
    # ========================================

    pass

    # ========================================
    # SCENARIO 4 : BOTH DCACHE & ICACHE READS
    # ========================================

    pass