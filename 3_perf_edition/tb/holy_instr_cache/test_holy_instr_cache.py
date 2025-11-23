# CACHE TESTBECH
#
# BRH 10/24
# Modif by BRH 05/25 : Verify manual flush support
# Modif by BRH 05/25 : Convert into DATA CACHE : add non cachable ranges support
# Modif by BRH 11/25 : This is now a instr cache only
#
# Post for guidance : https://0bab1.github.io/BRH/posts/TIPS_FOR_COCOTB/

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

# https://github.com/alexforencich/cocotbext-axi
DEADLOCK_THRESHOLD = 10e3

# CACHE STATES CST
IDLE                        = 0b0000
SENDING_WRITE_REQ           = 0b0001
SENDING_WRITE_DATA          = 0b0010
WAITING_WRITE_RES           = 0b0011

SENDING_READ_REQ            = 0b0101
RECEIVING_READ_DATA         = 0b0110
LITE_SENDING_WRITE_REQ      = 0b0111
LITE_SENDING_WRITE_DATA     = 0b1000
LITE_WAITING_WRITE_RES      = 0b1001
LITE_SENDING_READ_REQ       = 0b1010
LITE_RECEIVING_READ_DATA    = 0b1011
CPU_PERIOD = 10
SIZE = 2**10
CACHE_SIZE = 128 # 7 bits addressable

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
async def main_test(dut):

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "axi"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    await RisingEdge(dut.clk)
    await reset(dut)

    # ----------------------
    # we run these test multiple times with no resets, to check that going through states does
    # not affect default bahavior. e.g :  forgor to reset some AXI / AX LITE flags to default
    for k in range(10) :
        # Set cachable range to 0 for now to fully test the cache
        dut.cache_system.non_cachable_base.value = 0x0000_0000
        dut.cache_system.non_cachable_limit.value = 0x0000_0000

        # ==================================
        # MEMORY INIT WITH RANDOM VALUES
        # ==================================

        # We create a golden reference where we'll apply our changes as well and then compare
        mem_golden_ref = []
        for address in range(0,SIZE,4):
            word = generate_random_bytes(4)
            axi_ram_slave.write(address, word)
            mem_golden_ref.append(word)

        for address in range(0,SIZE,4):
            assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)

        # Do the same for the AXI LITE RAM
        lite_mem_golden_ref = []
        for address in range(0,SIZE,4):
            word = generate_random_bytes(4)
            axi_lite_ram_slave.write(address, word)
            lite_mem_golden_ref.append(word)

        for address in range(0,SIZE,4):
            assert lite_mem_golden_ref[int(address/4)] == axi_lite_ram_slave.read(address, 4)

        # ==================================
        # INIT STATE CHECKS
        # ==================================

        assert dut.cache_system.state.value == IDLE
        assert dut.cache_system.next_state.value == IDLE

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

        await RisingEdge(dut.clk) # STATE SWITCH
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

        await RisingEdge(dut.clk) # STATE SWITCH
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == RECEIVING_READ_DATA
        
        assert dut.axi_arvalid.value == 0b0
        assert dut.axi_rready.value == 0b1

        i = 0
        while( (not dut.axi_rvalid.value == 1) and (not i > DEADLOCK_THRESHOLD)) :
            await RisingEdge(dut.clk)
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
            await RisingEdge(dut.clk)
            await Timer(1, units="ps")

        # set_ptr = 126, set_ptr = 127 is the last
        assert dut.axi_rvalid.value == 0b1 and dut.axi_rready.value == 0b1
        assert dut.axi_rlast.value == 0b1
        assert dut.cache_system.next_state.value == IDLE

        await RisingEdge(dut.clk) # STATE SWITCH
        await Timer(1, units="ps")
        await RisingEdge(dut.clk) # SEQ STALL DE-ASSERTED
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

        await RisingEdge(dut.clk) # STATE SWITCH
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == SENDING_WRITE_REQ
        assert dut.cache_system.csr_flushing.value == 0b0

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

        await RisingEdge(dut.clk) # STATE SWITCH
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
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")

        # LAST write
        assert (dut.axi_wvalid.value == 1) and (dut.axi_wready.value == 1)
        assert dut.axi_wlast.value == 0b1
        assert dut.cache_system.next_state.value == WAITING_WRITE_RES

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == WAITING_WRITE_RES
        assert dut.cache_system.csr_flushing.value == 0b0
        assert dut.axi_wvalid.value == 0b0
        assert dut.axi_bready.value == 0b1

        i = 0
        while (not dut.axi_bvalid.value == 0b1) and (not i > DEADLOCK_THRESHOLD):
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")
            i += 1

        assert dut.axi_bvalid.value == 0b1
        assert dut.axi_bresp.value == 0b00 # OKAY

        # Check if memory was well written using golden ref
        for address in range(0,SIZE,4):
            assert mem_golden_ref[int(address/4)] == axi_ram_slave.read(address, 4)

        
        # After write_back is done, we can read
        assert dut.cache_system.next_state.value == SENDING_READ_REQ

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == SENDING_READ_REQ

        # assert the handshake is okay
        assert dut.axi_arvalid.value == 0b1
        assert dut.axi_arready.value == 0b1
        assert dut.axi_araddr.value == wb_test_addr & 0b111_0000000_00

        assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

        await RisingEdge(dut.clk) # STATE SWITCH !
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
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")

        assert dut.axi_rvalid.value == 0b1
        assert dut.axi_rready.value == 0b1
        assert dut.axi_rlast.value == 0b1
        assert dut.cache_system.next_state.value == IDLE

        await RisingEdge(dut.clk) # STATE SWITCH
        await Timer(1, units="ns")
        await RisingEdge(dut.clk) # SEQ STALL DE-ASSERTED
        await Timer(1, units="ns")

        # cache should also be flagged clean now
        assert dut.cache_system.cache_dirty.value == 0b0
        
        assert dut.cache_system.state.value == IDLE
        assert dut.cache_system.cache_stall.value == 0b0
        dut.axi_rlast.value = 0b0 # todo : rlast matter to handle

        # ==================================
        # READ CACHE MISS TEST
        # ==================================

        dut.cpu_address.value = 0x008 # NOT IN CACHE
        dut.cpu_byte_enable.value = 0b1111
        dut.cpu_write_enable.value = 0b1
        dut.cpu_read_enable.value = 0b0
        dut.cpu_write_data.value = 0xFFFFFFFF
        await Timer(1, units="ns")

        assert dut.cache_system.next_state.value == SENDING_READ_REQ
        assert dut.cpu_cache_stall.value == 0b1 # miss

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == SENDING_READ_REQ
        assert dut.axi_arvalid.value == 0b1
        assert dut.axi_arready.value == 0b1
        assert dut.axi_araddr.value == 0x000

        assert dut.cache_system.next_state.value == RECEIVING_READ_DATA

        await RisingEdge(dut.clk) # STATE SWITCH !
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
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")

        assert dut.axi_rvalid.value == 0b1
        assert dut.axi_rready.value == 0b1
        assert dut.axi_rlast.value == 0b1
        assert dut.cache_system.cache_stall.value == 0b1 
        assert dut.cache_system.next_state.value == IDLE

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")
        await RisingEdge(dut.clk) # SEQ STALL DE-ASSERTED
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == IDLE
        assert dut.cache_system.cache_stall.value == 0b0

        # check our write signals and data isn't written yet
        assert dut.cpu_address.value == 0x008
        assert dut.cpu_byte_enable.value == 0b1111
        assert dut.cpu_write_enable.value == 0b1
        assert dut.cpu_read_enable.value == 0b0 
        assert dut.cpu_write_data.value == 0xFFFFFFFF
        # assert not read_cache(dut.cache_system.cache_data,int(8/4)) == 0xFFFFFFFF shitty timing, fix maybe ?

        assert dut.cache_system.next_state.value == IDLE

        await RisingEdge(dut.clk) # write 0xFFFFFFFF @ 0x4
        await Timer(3, units="ns")

        dut.cpu_write_enable.value = 0b0
        await Timer(1, units="ns")

        assert read_cache(dut.cache_system.cache_data,int(8/4)) == 0xFFFFFFFF

        # ==================================
        # MANUAL FLUSH TEST
        # ==================================

        # do nothing for a bit
        await Timer(100, units="ns")
        await RisingEdge(dut.clk)

        # The user decides to manually fush the core
        dut.cache_system.csr_flush_order.value = 0b1
        await Timer(1, units="ns")
        # cach is dirty so next state shall be WRITE
        assert dut.cache_system.cache_dirty.value == 0b1
        assert dut.cache_system.next_state.value == SENDING_WRITE_REQ
        assert dut.cpu_cache_stall.value == 0b1

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        assert dut.cache_system.state.value == SENDING_WRITE_REQ
        assert dut.cache_system.csr_flushing.value == 0b1
        assert dut.axi_awvalid.value == 0b1
        assert dut.axi_arready.value == 0b1

        while not dut.cache_system.state.value == WAITING_WRITE_RES:
            # wait for next IDLE state
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")

        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        # after WB flush, we go straight to IDLE and bypass read
        assert dut.axi_bvalid.value == 0b1
        assert dut.axi_bresp.value == 0b00
        assert dut.cache_system.csr_flushing.value == 0b1
        assert dut.cache_system.next_csr_flushing.value == 0b0
        assert dut.cache_system.next_state.value == IDLE
        dut.cache_system.csr_flush_order.value = 0b0
        
        # csr flushin should be low again
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        assert dut.cache_system.csr_flushing.value == 0b0

        # wait for flush to be finished
        while not dut.cache_system.state.value == IDLE :
            await RisingEdge(dut.clk)

        # ==================================
        # NON CACHABLE RANGE WRITE TEST
        # ==================================

        # Set the non cachable range that will use AXI LITE for communication with axi_lite_ram tb slave
        # Set cachable range to 0 for now to fully test the cache
        dut.cache_system.non_cachable_base.value = 0x0000_0000
        dut.cache_system.non_cachable_limit.value = 0x0000_0800
        dut.cpu_byte_enable.value = 0b1111 # We fix write to full words for now. TODO : set axi_lite.wstrb to siupport this ! 10min job !
        await Timer(1, units="ns")

        # Now prepare a write request from the CPU, state should go towards LITE_SENDING_WRITE_REQ
        # TEST CORRECTION BRH : also get addres out ouf cached to test edge case on hit signal...
        dut.cpu_address.value = 0x404 # in the non cachable range ! AND not cached as well
        dut.cpu_write_enable.value = 0b1
        dut.cpu_read_enable.value = 0b0
        dut.cpu_write_data.value = 0xABCDABCD # data we are looking to write ...
        await Timer(1, units="ns") # propagate ...

        # whithout a clock cycle, the core should stall and next state should be LITE_SENDING_WRITE_REQ
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.non_cachable.value == 0b1
        assert dut.cache_system.next_state.value == LITE_SENDING_WRITE_REQ

        # Then we switch to AXI LITE write
        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")
        
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.non_cachable.value == 0b1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_REQ

        # Assuming memory is ready, request is acknowledged and we are about to sed data
        assert dut.axi_lite_arready.value == 1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_REQ
        assert dut.cache_system.next_state.value == LITE_SENDING_WRITE_DATA

        # Then we switch to sending the data...
        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        # assume memory is ready, check the data is the one expected and state is about to switch..
        assert dut.axi_lite_wvalid.value == 0b1
        assert dut.axi_lite_wready.value == 0b1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_DATA
        assert dut.cache_system.next_state.value == LITE_WAITING_WRITE_RES
        assert dut.axi_lite_wdata.value == 0xABCDABCD

        # Then we switch to sending the data...
        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")
        await RisingEdge(dut.clk) # wait for bvalid manually...
        await Timer(1, units="ns")

        # We are now waiting for a response from the memory... we assume it is instantly given
        assert dut.axi_lite_bready.value == 0b1
        assert dut.axi_lite_bvalid.value == 0b1
        assert dut.axi_lite_bresp.value == 0b00 # "OKAY" code
        assert dut.cache_system.next_state.value == IDLE

        # Check that the data was written correctly to the axi lite ram slave
        assert axi_lite_ram_slave.read(0x0000_0404, 4) == 0xABCDABCD.to_bytes(4, 'little')
        # update the golden ref
        lite_mem_golden_ref[int(0x0000_0404/4)] = 0xABCDABCD

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        # ==================================
        # NON CACHABLE RANGE READ TEST
        # ==================================

        # check init state after a write sequence... everythin should be back to default !
        assert dut.cache_system.state.value == IDLE
        # aw
        assert dut.axi_lite_awvalid.value == 0b0
        # w
        assert dut.axi_lite_wvalid.value == 0b0
        # b
        assert dut.axi_lite_bready.value == 0b0
        # ar
        assert dut.axi_lite_arvalid.value == 0b0
        # r
        assert dut.axi_lite_rready.value == 0b0

        # Also, the cache should flag its axi_result as done to prevent next_state leanving IDLE instantly..
        assert dut.cache_system.axi_lite_tx_done.value == 0b1
        assert dut.cache_system.next_axi_lite_tx_done.value == 0b0 # and it should auto reset ...


        await RisingEdge(dut.clk) # let the tx_done flag go low ...
        await Timer(1, units="ns")

        # stop interracting, wait a bit and check for stall to stay low !
        dut.cpu_write_enable.value = 0b0
        dut.cpu_read_enable.value = 0b0
        await Timer(1, units="ns")

        for _ in range(10):
            await RisingEdge(dut.clk)
            assert dut.cpu_cache_stall.value == 0b0

        # we have to test the exactitude of the read and that the actual output data is the right one
        # memory r slave is init to random values, we pick an arbitrary address whithing the non cachable range.
        addr = k*4

        dut.cpu_write_enable.value = 0b0
        dut.cpu_read_enable.value = 0b1
        dut.cpu_address.value = addr
        await Timer(5, units="ns") # propagate

        # cpu should stall immediatly and prepare to switch state to LITE_SENDING_READ_REQ
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.non_cachable.value == 0b1
        assert dut.cache_system.next_state.value == LITE_SENDING_READ_REQ
        # should immediatly start outputtin the data in axi_read_result,(even if its outdated)
        old_data_in_axi_read_result = dut.cache_system.axi_lite_read_result.value
        assert dut.cache_system.read_data.value == old_data_in_axi_read_result

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        # assuming memory is ready... req is ack and we switch to recieving the data
        assert dut.axi_lite_arready == 0b1
        assert dut.axi_lite_arvalid == 0b1
        assert dut.axi_lite_araddr == addr
        assert dut.cache_system.state.value == LITE_SENDING_READ_REQ
        assert dut.cache_system.next_state.value == LITE_RECEIVING_READ_DATA

        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")
        await RisingEdge(dut.clk) # wait for rvalid manually
        await Timer(1, units="ns")

        # We are recieving the incomming data, asuming memory sends valid data
        assert dut.cache_system.state.value == LITE_RECEIVING_READ_DATA
        assert dut.axi_lite_rready.value == 0b1
        assert dut.axi_lite_rvalid.value == 0b1
        # check that we recieve the expected data form the right addr ...
        assert int(dut.axi_lite_rdata.value).to_bytes(4,'little') == lite_mem_golden_ref[int(addr/4)]
        expected_axi_result = dut.axi_lite_rdata.value
        assert dut.cache_system.next_state.value == IDLE
        
        await RisingEdge(dut.clk) # STATE SWITCH !
        await Timer(1, units="ns")

        # check that we are in IDLE, not stalling anymore and sending the right data to the cpu !
        assert dut.cache_system.state.value == IDLE
        assert dut.cache_system.axi_lite_read_result.value == expected_axi_result
        assert dut.cpu_read_data.value == expected_axi_result
        dut.cpu_read_enable.value = 0b0
        await Timer(1, units="ns")

        assert dut.cpu_cache_stall.value == 0b0

        # everythin should be back to default !
        assert dut.cache_system.state.value == IDLE
        # aw
        assert dut.axi_lite_awvalid.value == 0b0
        # w
        assert dut.axi_lite_wvalid.value == 0b0
        # b
        assert dut.axi_lite_bready.value == 0b0
        # ar
        assert dut.axi_lite_arvalid.value == 0b0
        # r
        assert dut.axi_lite_rready.value == 0b0

        # stop interracting, wait a bit and check for stall to stay low !
        dut.cpu_write_enable.value = 0b0
        dut.cpu_read_enable.value = 0b0
        await Timer(1, units="ns")

        for _ in range(10):
            await RisingEdge(dut.clk)
            assert dut.cpu_cache_stall.value == 0b0

        # And now we create a cache miss to a large address
        # (next looped tests nedd to miss)

        dut.cpu_read_enable.value = 0b1
        dut.cpu_address.value = 0xAEAE_AEA0
        await Timer(1, units="ns")
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        assert dut.cache_system.state.value == SENDING_WRITE_REQ

        while not dut.cache_system.state.value == IDLE:
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")

        # seq stall de assert
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
