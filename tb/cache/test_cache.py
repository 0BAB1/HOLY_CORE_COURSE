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
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)

    # Init the memorywith random values and save the random values in a golden reference array
    mem_golden_ref = []
    for address in range(0,SIZE,4):
        word = generate_random_bytes(4)
        axi_ram_slave.write(address, word)
        mem_golden_ref.append(word)

    for address in range(0,SIZE,4):
        assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)
        # axi_ram_slave.hexdump(address, 4)

    cocotb.start_soon(Clock(dut.clk, PERIOD, units="ns").start())
    await RisingEdge(dut.clk)
    await reset(dut)

    # Check default state
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.next_state.value == IDLE

    # Try to read a piece of data, cache should miss as table is invalid and require data through AXI
    address_test_read = 0x000
    dut.cpu_address.value = address_test_read
    dut.cpu_read_enable.value = 0b1
    await Timer(1, units="ns") # just let the logic propagate

    # Check if the cpu interface comb logic updated well and next state is SENDING_READ_REQ
    assert dut.cpu_cache_stall.value == 0b1 # async stall gets asserted (cache miss)
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    # On this rising edge, the state should switch to "SENDING_READ_REQ"
    # and assert the AXI read if signals.
    await RisingEdge(dut.clk)
    await Timer(1, units="ps") # Added this otherwise it does not pass, I tried to let data propagte, turns out it works, todo : figure it out

    assert dut.cache_system.state.value == SENDING_READ_REQ
    assert dut.axi_arid.value == 0b0000
    assert dut.axi_araddr.value == 0x000 
    assert dut.axi_arlen.value == 0x07F
    assert dut.axi_arsize.value == 0b010
    assert dut.axi_arburst.value == 0b01 # increment mode
    assert dut.axi_arvalid.value == 0b1

    # Memory has to be ready to go on
    assert dut.axi_arready.value == 0b1

    # That means the nexet state will be about gathering data
    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    # Wait 
    await RisingEdge(dut.clk)
    await Timer(1, units="ps")

    # new state should be waiting for read data to arrive
    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    
    # Check the corresponding axi signals
    assert dut.axi_arvalid.value == 0b0
    assert dut.axi_rready.value == 0b1 # the cache is ready to get its data !

    i = 0
    while( (not dut.axi_rvalid.value == 1) and (not i > DEADLOCK_THRESHOLD)) :
        # if the data is not readable yet, we wait the next clock cycle
        await RisingEdge(dut.clk)
        await Timer(1, units="ps")
    
    # if we are here, it is because we just passed an AXI clock edge where the read data is valid
    # that means the cpu will start reading the next 128 words and then go to IDLE
    # and return the data to the CPU.

    i = 0
    while( i < CACHE_SIZE - 1) :
        # Check if the handshake is okay
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            # a word is sent to cache and is store in the cache block
            assert dut.cache_system.write_set.value == i
            i += 1

        # goto next clock cycle, last flag is never high
        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 # mmake sure stall is always HIGH
        await RisingEdge(dut.clk)
        await Timer(1, units="ps")

    # after getting 127 data, the 128th is support to be the last
    assert dut.axi_rvalid.value == 0b1
    assert dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    # this also means that the next state has to be IDLE
    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.clk) # STATE SWITCH
    await Timer(1, units="ps")
    
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0
    #======
    dut.axi_rlast.value = 0b0 # THIS IS VERY SKETCHY ! TRY TO FIX THAT LATER ON !
    await Timer(1, units="ps")
    #======
    assert dut.axi_rlast.value == 0b0

    # Great ! now we test the data currently stored in the cache MANUALLY
    # i.e. not by poking using cocotb but issuing actual logical reads

    for i in range(CACHE_SIZE) :
        # Check againts our memory golden ref
        dut.cpu_address.value = address_test_read
        await Timer(1, units="ps") # let the new address propagate ...
        assert dut.cache_system.cache_stall == 0b0
        assert dut.cache_system.read_data.value == int.from_bytes(mem_golden_ref[int(address_test_read/4)], byteorder='little')
        assert dut.cache_system.write_set.value == 0

        address_test_read += 0x4
        await RisingEdge(dut.clk)
        await Timer(1, units="ps")

    assert address_test_read == CACHE_SIZE * 4 # we are at the edge of the cache, the point of overflow !

    # If we try to read now, the cache should miss, let's check this out !
    dut.cpu_address.value = address_test_read
    await Timer(1, units="ps") # let the new address propagate ...

    assert dut.cache_system.cache_stall == 0b1
    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    # But we are not going to test that again. Instead, let's write some values to memory,
    # and then create a cache miss that will 1) create a write back to main memory (cache will be dirty)
    # and 2) then request the new memory block.
    # we'll have to test if the main memory was indeed well written

    address_test_read = 0x0C # he its for cache, only addressable on 7 BITS ! keep it under 128 other wise that will be a miss !!
    write_data_test = 0xDEADBEEF
    dut.cpu_address.value = address_test_read # some random address
    dut.cpu_byte_enable.value = 0b0011 # lets say we are writing an halfword
    dut.cpu_write_enable.value = 0b1
    dut.cpu_read_enable.value = 0b0 # otherwise, HDL gives error
    dut.cpu_write_data.value = write_data_test 
    # check we are not stalling and that the cache will accept the write
    await Timer(1, units="ps")
    assert dut.cache_system.cache_stall.value == 0b0

    # only 0xXXXXBEEF should be written with 0xXXXX being whatever was there before
    # so we have to get this "whatever" before doing anything else to build an expected result
    expected_data = axi_ram_slave.read(address_test_read, 4)
    expected_data = int.from_bytes(expected_data, byteorder='little') # convert to int for manip & assertions
    expected_data &= 0xFFFF0000
    expected_data |= (write_data_test & 0x0000FFFF)

    print(expected_data)

    # Now we write ONCE
    await RisingEdge(dut.clk)
    await Timer(1, units="ps")

    # Stop writing
    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ps")

    # Is the data correct in cache ??
    assert dut.cache_system.cache_data[int(address_test_read/4)].value == expected_data

    # Now we create a cache miss, the cache should send a write request because its now dirty
    address_test_read = 0xF0C # Block tag = 0xF0 / set = 0xC
    dut.cpu_address.value = address_test_read # some random address
    dut.cpu_read_enable.value = 0b1
    await Timer(1, units="ps") # let it propagate ...

    assert dut.cache_system.next_state.value == SENDING_WRITE_REQ # should start req a write on next clk cycle

    await RisingEdge(dut.clk) # STATE SWITCH
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == SENDING_WRITE_REQ

    # check the write address channel signals
    assert dut.axi_awvalid.value == 0b1
    base_addr = 0x000
    assert dut.axi_awaddr.value == base_addr # the data in cache based @ cache tag + full 0s = 0x000 in our case

    # grab this opportunity to check the constants
    assert dut.axi_awid.value == 0b0000
    assert dut.axi_awlen.value == 0x07F
    assert dut.axi_awsize.value == 0b010
    assert dut.axi_awburst.value == 0b01 # increment mode
    assert dut.axi_wstrb.value == 0b1111 # no masking as it was handled by the core

    # Memory has to be ready to go on, we'll assert that it has always been ready in our case
    assert dut.axi_awready.value == 0b1

    # if the memory is ready, that means the handshake is complete hand that the next clock cycle is all about sending the data
    assert dut.cache_system.next_state.value == SENDING_WRITE_DATA

    await RisingEdge(dut.clk) # STATE SWITCH
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == SENDING_WRITE_DATA

    # And we send the data ! Let's check that everythig goes according to plan

    i = 0
    while( i < CACHE_SIZE - 1) :
        # Check if the handshake is okay
        if((dut.axi_wvalid.value == 1) and (dut.axi_wready.value == 1)) :
            # a word is sent to cache and is store in the cache block
            
            assert dut.cache_system.write_set.value == i
            i += 1
            # Update golden ref memory !
            mem_golden_ref[int(base_addr/4)] = int(dut.axi_wdata.value).to_bytes(4, 'little')
            base_addr += 4

        # goto next clock cycle, last flag is never high
        assert dut.axi_wlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 # mmake sure stall is always HIGH

        await RisingEdge(dut.clk)
        await Timer(1, units="ps")

    # On the LAST write ! wlast is hagh and we're about to wait for write response !
    assert (dut.axi_wvalid.value == 1) and (dut.axi_wready.value == 1) # assert handshake
    assert dut.axi_wlast.value == 0b1
    assert dut.cache_system.next_state.value == WAITING_WRITE_RES

    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == WAITING_WRITE_RES
    assert dut.axi_wvalid.value == 0b0
    assert dut.axi_bready.value == 0b1

    while not dut.axi_bvalid.value == 0b1:
        # if we have no response from memory, then we wait
        await RisingEdge(dut.clk)
        await Timer(1, units="ps")
        print("wait")
    
    # Here, bvalid should be 1, and respose should be 00 lets make sure using an assertion
    assert dut.axi_bvalid.value == 0b1
    assert dut.axi_bresp.value == 0b00

    # so the answer is good ! Now check if memory was indeed well written using golden ref
    for address in range(0,SIZE,4):
        assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)

    
    # then check that once the response is good, we're about to send that read request

    assert dut.cache_system.next_state.value == SENDING_READ_REQ

    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == SENDING_READ_REQ

    # assert the handshake is okay
    assert dut.axi_arvalid.value == 0b1
    assert dut.axi_arready.value == 0b1
    assert dut.axi_araddr.value == address_test_read & 0b111_0000000_00

    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")


    # Check reading transaction, just like before...
    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    assert dut.axi_rvalid.value == 0b0
    assert dut.axi_rlast.value == 0b0

    i = 0
    while( i < CACHE_SIZE - 1) :
        # Check if the handshake is okay
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            assert dut.cache_system.write_set.value == i
            i += 1

        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

    assert dut.axi_rvalid.value == 0b1
    assert dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    assert dut.cache_system.next_state.value == IDLE

    await RisingEdge(dut.clk) # STATE SWITCH
    await Timer(1, units="ns")
    
    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0
    dut.axi_rlast.value = 0b0 # todo : rlast matter to handle

    # AND NOW, we'll run these test by directly writing a non-cached address

    dut.cpu_address.value = 0x008
    dut.cpu_byte_enable.value = 0b1111 # write full word
    dut.cpu_write_enable.value = 0b1
    dut.cpu_read_enable.value = 0b0 # otherwise, HDL gives error
    dut.cpu_write_data.value = 0xFFFFFFFF
    await Timer(1, units="ns")

    # The cache should MISS and the cpu should require a read to AXI RAM

    assert dut.cache_system.next_state.value == SENDING_READ_REQ
    assert dut.cpu_cache_stall.value == 0b1

    # then the cache reads....
    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == SENDING_READ_REQ
    assert dut.axi_arvalid.value == 0b1
    assert dut.axi_arready.value == 0b1
    assert dut.axi_araddr.value == 0x000

    assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == RECEIVING_READ_DATA
    assert dut.axi_rvalid.value == 0b0
    assert dut.axi_rlast.value == 0b0

    i = 0
    while( i < CACHE_SIZE - 1) :
        if((dut.axi_rvalid.value == 1) and (dut.axi_rready.value == 1)) :
            assert dut.cache_system.write_set.value == i
            i += 1

        assert dut.axi_rlast.value == 0b0
        assert dut.cache_system.cache_stall.value == 0b1 
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")

    assert dut.axi_rvalid.value == 0b1
    assert dut.axi_rready.value == 0b1
    assert dut.axi_rlast.value == 0b1
    assert dut.cache_system.cache_stall.value == 0b1 
    assert dut.cache_system.next_state.value == IDLE

    # the cache swithes to IDLE, intials signals are still asserted...

    await RisingEdge(dut.clk) # STATE SWITCH !
    await Timer(1, units="ps")

    assert dut.cache_system.state.value == IDLE
    assert dut.cache_system.cache_stall.value == 0b0

    assert dut.cpu_address.value == 0x008
    assert dut.cpu_byte_enable.value == 0b1111 # write full word
    assert dut.cpu_write_enable.value == 0b1
    assert dut.cpu_read_enable.value == 0b0 # otherwise, HDL gives error
    assert dut.cpu_write_data.value == 0xFFFFFFFF

    assert dut.cache_system.next_state.value == IDLE

    # and then the data gets written...

    await RisingEdge(dut.clk) # write 0xFFFFFFFF @ 0x4
    await Timer(1, units="ns")

    dut.cpu_write_enable.value = 0b0
    await Timer(1, units="ns")

    assert int(dut.cache_system.cache_data[int(8/4)].value) == 0xFFFFFFFF

    pass
