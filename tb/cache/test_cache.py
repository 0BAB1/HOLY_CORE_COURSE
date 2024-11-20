import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam
import numpy as np

# https://github.com/alexforencich/cocotbext-axi

# To test for cache behavior and code validation :
# AXI external query for data
# Basic Read/Write (regular meomory test)
# New AXI external query, check for writeback

# for now, axi clk / rst and cache clk / rst are the SAME

# CACHE STATES CST
IDLE                = 0b000
SENDING_WRITE_REQ   = 0b001
SENDING_WRITE_DATA  = 0b010
WAITING_WRITE_RES   = 0b011
SENDING_READ_REQ    = 0b100
RECEIVING_READ_DATA = 0b101

def generate_random_bytes(length):
    return bytes([random.randint(0, 255) for _ in range(length)])

@cocotb.coroutine
async def reset(dut):
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.cpu_write_enable.value = 0
    dut.cpu_address.value = 0
    dut.cpu_write_data.value = 0
    dut.cpu_byte_enable.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    print("reset done !")

    # Assert all is 0 after reset
    for cache_line in range(dut.cache_system.CACHE_SIZE.value):
        assert int(dut.cache_system.cache_data[cache_line].value) == 0

@cocotb.test()
async def initial_read_test(dut):
    """In this test, the inital valid flag should be 0, meaning we have to send a read query"""
    SIZE = 4096 # 4kB adressable by 3B/12b
    CACHE_SIZE = 128 #7 b addressable, SYNC IT WITH THE ACTUAL TB CACHE SIZE
    PERIOD = 10
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n, size=SIZE)

    # Init the memorywith random values and save the random values in a golden reference array
    mem_golden_ref = []
    for address in range(0,SIZE,4):
        word = generate_random_bytes(4)
        axi_ram_slave.write(address, word)
        mem_golden_ref.append(word)
        # print(word)
    
    # print(mem_golden_ref)

    for address in range(0,SIZE,4):
        assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)
        # axi_ram_slave.hexdump(address, 4)

    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await RisingEdge(dut.clk)
    await reset(dut)

    # Check default state
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.next_state.value == IDLE

    # Try to read a piece of data, cache should miss as table is invalid and require data through AXI
    dut.cpu_address.value = 0x000
    dut.cpu_read_enable.value = 0b1
    await Timer(1, units="ns") # just let the logic propagate

    # Check if the cpu interface comb logic updated well and next state is SENDING_READ_REQ
    assert dut.cpu_cache_stall.value == 0b1
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    # On this rising edge, the state should switch to "SENDING_READ_REQ"
    # and assert the AXI read if signals.
    await RisingEdge(dut.clk)

    assert dut.axi_arid.value == 0b0000
    assert dut.axi_araddr.value == 0x000 
    assert dut.axi_arlen.value == 0x07F + 0b1
    assert dut.axi_arsize.value == 4
    assert dut.axi_arburst.value == 0b00
    assert dut.axi_arvalid.value == 0b1

    # Memory has to be ready to go on
    assert dut.ar_ready.value == 0b1

    # That means the nexet state will be about gathering data
    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    # Wait 
    await RisingEdge(dut.clk)
    
    pass
