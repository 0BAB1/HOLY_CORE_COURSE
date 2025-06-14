# CACHE TESTBECH
#
# BRH 10/24
# Modif by BRH 05/25 : Verify manual flush support
# Modif by BRH 05/25 : Convert into DATA CACHE : add non cachable ranges support
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
SENDING_READ_REQ            = 0b0100
RECEIVING_READ_DATA         = 0b0101
LITE_SENDING_WRITE_REQ      = 0b0110
LITE_SENDING_WRITE_DATA     = 0b0111
LITE_WAITING_WRITE_RES      = 0b1000
LITE_SENDING_READ_REQ       = 0b1001
LITE_RECEIVING_READ_DATA    = 0b1010


# clock perdiods, if different, make sure AXI_PERIOD >= CPU_PERIOD
AXI_PERIOD = 10
CPU_PERIOD = 10

# Cach stuff
SIZE = 2**13 # adressable by 3B/12b
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

    #dump_cache(dut.cache_system.cache_data, "*")

@cocotb.test()
async def main_test(dut):

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.aclk, dut.rst_n, size=SIZE, reset_active_level=False)
    await RisingEdge(dut.clk)
    await reset(dut)

    # ----------------------
    # we run these test multiple times with no resets, to check that going through states does
    # not affect default bahavior. e.g :  forgor to reset some AXI / AX LITE flags to default
    for _ in range(10) :

        # ==================================
        # MEMORY INIT WITH RANDOM VALUES
        # ==================================

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
        # NON CACHED WRITE TEST
        # ==================================

        # Now prepare a write request from the CPU, state should go towards LITE_SENDING_WRITE_REQ
        # TEST CORRECTION BRH : also get addres out ouf cached to test edge case on hit signal...
        dut.cpu_address.value = 0x404 # in the non cachable range ! AND not cached as well
        dut.cpu_write_enable.value = 0b1
        dut.cpu_read_enable.value = 0b0
        dut.cpu_byte_enable.value = 0b1111
        dut.cpu_write_data.value = 0xABCDABCD # data we are looking to write ...
        await Timer(1, units="ns") # propagate ...

        # whithout a clock cycle, the core should stall and next state should be LITE_SENDING_WRITE_REQ
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.next_state.value == LITE_SENDING_WRITE_REQ

        # Then we switch to AXI LITE write
        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")
        
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_REQ

        # Assuming memory is ready, request is acknowledged and we are about to sed data
        assert dut.axi_lite_arready.value == 1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_REQ
        assert dut.cache_system.next_state.value == LITE_SENDING_WRITE_DATA

        # Then we switch to sending the data...
        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")

        # assume memory is ready, check the data is the one expected and state is about to switch..
        assert dut.axi_lite_wvalid.value == 0b1
        assert dut.axi_lite_wready.value == 0b1
        assert dut.cache_system.state.value == LITE_SENDING_WRITE_DATA
        assert dut.cache_system.next_state.value == LITE_WAITING_WRITE_RES
        assert dut.axi_lite_wdata.value == 0xABCDABCD

        # Then we switch to sending the data...
        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")
        await RisingEdge(dut.aclk) # wait for bvalid manually...
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

        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")

        # ==================================
        # NON CACHED READ TEST
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


        await RisingEdge(dut.aclk) # let the tx_done flag go low ...
        await Timer(1, units="ns")

        # stop interracting, wait a bit and check for stall to stay low !
        dut.cpu_write_enable.value = 0b0
        dut.cpu_read_enable.value = 0b0
        await Timer(1, units="ns")

        for _ in range(10):
            await RisingEdge(dut.aclk)
            assert dut.cpu_cache_stall.value == 0b0

        # we have to test the exactitude of the read and that the actual output data is the right one
        # memory r slave is init to random values, we pick an arbitrary address whithing the non cachable range.
        addr = 0x0000_000C

        dut.cpu_write_enable.value = 0b0
        dut.cpu_read_enable.value = 0b1
        dut.cpu_address.value = addr
        await Timer(1, units="ns") # propagate

        # cpu should stall immediatly and prepare to switch state to LITE_SENDING_READ_REQ
        assert dut.cpu_cache_stall.value == 0b1
        assert dut.cache_system.next_state.value == LITE_SENDING_READ_REQ
        # should immediatly start outputtin the data in axi_read_result,(even if its outdated)
        old_data_in_axi_read_result = dut.cache_system.axi_lite_read_result.value
        assert dut.cache_system.read_data.value == old_data_in_axi_read_result

        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")

        # assuming memory is ready... req is ack and we switch to recieving the data
        assert dut.axi_lite_arready == 0b1
        assert dut.axi_lite_arvalid == 0b1
        assert dut.axi_lite_araddr == addr
        assert dut.cache_system.state.value == LITE_SENDING_READ_REQ
        assert dut.cache_system.next_state.value == LITE_RECEIVING_READ_DATA

        await RisingEdge(dut.aclk) # STATE SWITCH !
        await Timer(1, units="ns")
        await RisingEdge(dut.aclk) # wait for rvalid manually
        await Timer(1, units="ns")

        # We are recieving the incomming data, asuming memory sends valid data
        assert dut.cache_system.state.value == LITE_RECEIVING_READ_DATA
        assert dut.axi_lite_rready.value == 0b1
        assert dut.axi_lite_rvalid.value == 0b1
        # check that we recieve the expected data form the right addr ...
        assert int(dut.axi_lite_rdata.value).to_bytes(4,'little') == lite_mem_golden_ref[int(0x0000_000C/4)]
        expected_axi_result = dut.axi_lite_rdata.value
        assert dut.cache_system.next_state.value == IDLE
        
        await RisingEdge(dut.aclk) # STATE SWITCH !
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
            await RisingEdge(dut.aclk)
            assert dut.cpu_cache_stall.value == 0b0
