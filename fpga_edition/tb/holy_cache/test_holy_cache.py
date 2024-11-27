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
# TODO : first ill check the BARE minumum and then, once I get somthing somewhat working, add aseertion on ALL interfaces

# for now, axi clk / rst and cache clk / rst are the SAME

# EDGE CASES TO TEST
# write the very last value in cache and checks that it gets written back to main mem when write-back happens

# Threshold to detect deadlocks in while loops
DEADLOCK_THRESHOLD = 10e3

# CACHE STATES CST
IDLE                = 0b000
SENDING_WRITE_REQ   = 0b001
SENDING_WRITE_DATA  = 0b010
WAITING_WRITE_RES   = 0b011
SENDING_READ_REQ    = 0b100
RECEIVING_READ_DATA = 0b101

# clock perdiods
AXI_PERIOD = 16
CPU_PERIOD = 10

# Cach stuff
SIZE = 4096 # 4kB adressable by 3B/12b
CACHE_SIZE = 128 #7 b addressable, SYNC IT WITH THE ACTUAL TB CACHE SIZE

def generate_random_bytes(length):
    return bytes([random.randint(0, 255) for _ in range(length)])

def read_cache(cache_data, line) :
    """To read cache_data, because the packed array makes it an array of bits... Fuck vivado, I mean it"""
    l = 127 - line
    return (int(str(cache_data.value[32*l:(32*l)+31]),2))

def dump_cache(cache_data, line) -> int :
    if line == "*" :
        for line_a in range(128): # for fixed cache size of 128
            l = 127 - line_a
            print(hex(int(str(cache_data.value[32*l:(32*l)+31]),2)))
    else :
        print(hex(int(str(cache_data.value[32*line:(32*line)+31]),2)))
        

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
        assert read_cache(dut.cache_system.cache_data, cache_line) == 0
        #assert int(dut.cache_system.cache_data[cache_line].value) == 0

    #dump_cache(dut.cache_system.cache_data, "*")

@cocotb.test()
async def initial_read_test(dut):
    """In this test, the inital valid flag should be 0, meaning we have to send a read query"""

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.aclk, dut.rst_n, size=SIZE, reset_active_level=False)
    await RisingEdge(dut.clk)
    await reset(dut)

    # ==================================
    # MEMORY INIT WITH RANDOM VALUES
    # ==================================

    mem_golden_ref = []
    for address in range(0,SIZE,4):
        word = generate_random_bytes(4)
        axi_ram_slave.write(address, word)
        mem_golden_ref.append(word)

    for address in range(0,SIZE,4):
        assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)

    

    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.next_state.value == IDLE

    # ==================================
    # BASIC STALL LOGIC 
    # ==================================

    dut.cpu_read_enable.value = 0b0
    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ps") # let the signals "propagate"

    dut.cpu_address.value = 0x000
    dut.cpu_read_enable.value = 0b0
    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ps") # let the signals "propagate"

    assert dut.cache_system.cache_stall.value == 0b0
    assert dut.cache_system.next_state.value == IDLE

    # ==================================
    # READ & MISS TEST
    # ==================================

    dut.cpu_address.value = 0x000
    dut.cpu_read_enable.value = 0b1
    await Timer(1, units="ps")

    assert dut.cpu_cache_stall.value == 0b1 # async cache miss
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ns")

    # Verify constant axi signals
    assert dut.cache_system.state.value == SENDING_READ_REQ
    assert dut.axi_arid.value == 0b0000
    assert dut.axi_araddr.value == 0x000 
    assert dut.axi_arlen.value == 0x07F
    assert dut.axi_arsize.value == 0b010
    assert dut.axi_arburst.value == 0b01 # increment mode
    assert dut.axi_arvalid.value == 0b1

    assert dut.axi_arready.value == 0b1

    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    
    assert dut.axi_arvalid.value == 0b0
    assert dut.axi_rready.value == 0b1

    i = 0
    while( (not dut.axi_rvalid.value == 1) and (not i > DEADLOCK_THRESHOLD)) :
        await RisingEdge(dut.aclk)
        await Timer(1, units="ns")

    i = 0
    while( i < CACHE_SIZE - 1) :
        # Check if the handshake is okay
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            # a word is sent to cache and is store in the cache block
            assert dut.cache_system.set_ptr.value == i
            i += 1

        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1
        await RisingEdge(dut.aclk)
        await Timer(1, units="ps")

    # set_ptr = 126, set_ptr = 127 is the last
    assert dut.axi_rvalid.value == 0b1 and dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ps")
    
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0
    #======
    dut.axi_rlast.value = 0b0 # THIS IS VERY SKETCHY ! TRY TO FIX THAT LATER ON !
    await Timer(1, units="ps")
    #======
    assert dut.axi_rlast.value == 0b0

    # ==================================
    # CACHE READ & NO MISS TEST
    # ==================================

    addr = 0x000
    for i in range(CACHE_SIZE) :
        # Check againts our memory golden ref
        dut.cpu_address.value = addr
        await Timer(1, units="ps")
        assert dut.cache_system.cache_stall == 0b0
        assert dut.cache_system.read_data.value == int.from_bytes(mem_golden_ref[int(addr/4)], byteorder='little')
        assert dut.cache_system.set_ptr.value == 0

        addr += 0x4
        await RisingEdge(dut.clk)
        await Timer(1, units="ps")

    assert addr == CACHE_SIZE * 4 

    # We are ouside of cache bounds. If we try to read now, the cache should miss.
    dut.cpu_address.value = addr
    await Timer(1, units="ps") # let the new address propagate ...

    assert dut.cache_system.cache_stall == 0b1
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    # ==================================
    # DIRTY CACHE & WRITE BACK & READ TEST
    # ==================================

    dut.cpu_address.value = 0x0C
    dut.cpu_byte_enable.value = 0b0011 # We write an halfword to cache
    dut.cpu_write_enable.value = 0b1
    dut.cpu_read_enable.value = 0b0
    dut.cpu_write_data.value = 0xDEADBEEF 
    # check we are not stalling and that the cache will accept the write
    await Timer(1, units="ns")
    assert dut.cache_system.cache_stall.value == 0b0

    # Build expected value for later assertion
    expected_data = axi_ram_slave.read(0x0C, 4)
    expected_data = int.from_bytes(expected_data, byteorder='little') # convert to int for manip & assertions
    expected_data &= 0xFFFF0000
    expected_data |= (0xDEABEEF & 0x0000FFFF)

    # CPU Writes cache
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    # Stop writing
    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ns")

    assert read_cache(dut.cache_system.cache_data,int(0x0C/4)) == expected_data
    assert dut.cache_system.cache_dirty.value == 0b1

    wb_test_addr = 0xF0C
    dut.cpu_address.value = wb_test_addr # Not in cache
    dut.cpu_read_enable.value = 0b1
    await Timer(1, units="ns") 

    # Cache miss : The cache should send a write request because it's now dirty
    assert dut.cache_system.next_state.value == SENDING_WRITE_REQ

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == SENDING_WRITE_REQ

    assert dut.axi_awvalid.value == 0b1
    # awaddr writes back the current cached tag, i.e. 0x000
    assert dut.axi_awaddr.value == 0x000 

    # check the w channels constants
    assert dut.axi_awid.value == 0b0000
    assert dut.axi_awlen.value == 0x07F
    assert dut.axi_awsize.value == 0b010
    assert dut.axi_awburst.value == 0b01 # increment mode
    assert dut.axi_wstrb.value == 0b1111 # no masking (handled by core)

    assert dut.axi_awready.value == 0b1

    assert dut.cache_system.next_state.value == SENDING_WRITE_DATA

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == SENDING_WRITE_DATA

    # Write back transaction

    i = 0
    addr = 0x000
    while( i < CACHE_SIZE - 1) :
        # Check if the handshake is okay
        if((dut.axi_wvalid.value == 1) and (dut.axi_wready.value == 1)) :
            assert dut.cache_system.set_ptr.value == i
            i += 1
            # Update golden ref memory !
            mem_golden_ref[int(addr/4)] = int(dut.axi_wdata.value).to_bytes(4, 'little')
            addr += 4

        assert dut.axi_wlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1
        await RisingEdge(dut.aclk)
        await Timer(1, units="ns")

    # LAST write
    assert (dut.axi_wvalid.value == 1) and (dut.axi_wready.value == 1)
    assert dut.axi_wlast.value == 0b1
    assert dut.cache_system.next_state.value == WAITING_WRITE_RES

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == WAITING_WRITE_RES
    assert dut.axi_wvalid.value == 0b0
    assert dut.axi_bready.value == 0b1

    i = 0
    while (not dut.axi_bvalid.value == 0b1) and (not i > DEADLOCK_THRESHOLD):
        await RisingEdge(dut.aclk)
        await Timer(1, units="ns")
        i += 1

    assert dut.axi_bvalid.value == 0b1
    assert dut.axi_bresp.value == 0b00 # OKAY

    # Check if memory was well written using golden ref
    for address in range(0,SIZE,4):
        assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)

    
    # After write_back is done, we can read
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == SENDING_READ_REQ

    # assert the handshake is okay
    assert dut.axi_arvalid.value == 0b1
    assert dut.axi_arready.value == 0b1
    assert dut.axi_araddr.value == wb_test_addr & 0b111_0000000_00

    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    assert dut.axi_rvalid.value == 0b0
    assert dut.axi_rlast.value == 0b0

    i = 0
    while( i < CACHE_SIZE - 1) :
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            assert dut.cache_system.set_ptr.value == i
            i += 1

        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 
        await RisingEdge(dut.aclk)
        await Timer(1, units="ns")

    assert dut.axi_rvalid.value == 0b1
    assert dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.aclk) # STATE SWITCH
    await Timer(1, units="ns")
    
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0
    dut.axi_rlast.value = 0b0 # todo : rlast matter to handle

    # ==================================
    # WRITE CACHE MISS TEST
    # ==================================

    dut.cpu_address.value = 0x008 # NOT IN CACHE
    dut.cpu_byte_enable.value = 0b1111
    dut.cpu_write_enable.value = 0b1
    dut.cpu_read_enable.value = 0b0
    dut.cpu_write_data.value = 0xFFFFFFFF
    await Timer(1, units="ns")

    assert dut.cache_system.next_state.value == SENDING_READ_REQ
    assert dut.cpu_cache_stall.value == 0b1 # miss

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == SENDING_READ_REQ
    assert dut.axi_arvalid.value == 0b1
    assert dut.axi_arready.value == 0b1
    assert dut.axi_araddr.value == 0x000

    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    assert dut.axi_rvalid.value == 0b0
    assert dut.axi_rlast.value == 0b0

    i = 0
    while( i < CACHE_SIZE - 1) :
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            assert dut.cache_system.set_ptr.value == i
            i += 1

        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 
        await RisingEdge(dut.aclk)
        await Timer(1, units="ns")

    assert dut.axi_rvalid.value == 0b1
    assert dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    assert dut.cache_system.cache_stall.value == 0b1 
    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.aclk) # STATE SWITCH !
    await Timer(1, units="ns")

    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0

    # check our write signals and data isn't written yet
    assert dut.cpu_address.value == 0x008
    assert dut.cpu_byte_enable.value == 0b1111
    assert dut.cpu_write_enable.value == 0b1
    assert dut.cpu_read_enable.value == 0b0 
    assert dut.cpu_write_data.value == 0xFFFFFFFF
    assert not read_cache(dut.cache_system.cache_data,int(8/4)) == 0xFFFFFFFF

    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.clk) # write 0xFFFFFFFF @ 0x4
    await Timer(3, units="ns")

    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ns")

    assert read_cache(dut.cache_system.cache_data,int(8/4)) == 0xFFFFFFFF
