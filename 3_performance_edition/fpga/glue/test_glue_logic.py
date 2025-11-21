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
SIZE = 2**13

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
    dut.req_i.value = 0
    dut.add_i.value = 0
    dut.we_i.value = 0
    dut.wdata_i.value = 0
    dut.be_i.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    print("reset done !")

@cocotb.test()
async def main_test(dut):

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())
    cocotb.start_soon(Clock(dut.aclk, AXI_PERIOD, units="ns").start())
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "axi_lite"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    await RisingEdge(dut.clk)
    await reset(dut)

    # ----------------------
    # we run these test multiple times with no resets, to check that going through states does
    # not affect default bahavior. e.g :  forgor to reset some AXI / AX LITE flags to default
    for _ in range(100) :

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # ==================================
        # WRITE TEST
        # ==================================

        addr = 4*random.randint(0,SIZE/4)
        wdata = random.randint(0,0xFFFFFFFF)
        dut.req_i.value = 1
        dut.wdata_i.value = wdata
        dut.add_i.value = addr
        dut.we_i.value = 1
        dut.be_i.value = 0xF
        await RisingEdge(dut.clk)

        while dut.dm_top_to_axi_lite_glue.mst_pulp_axi.b_valid != 1:
            # as long as we don't have an answere internally, we wait
            # for write to complete
            await RisingEdge(dut.clk)
            dut.req_i.value = 0
            dut.we_i.value = 0
            dut.be_i.value = 0x0

        # check that the memory recieved it
        assert int.from_bytes(axi_lite_ram_slave.read(addr, 4),'little') == wdata

        # ==================================
        # READ TEST
        # ==================================

        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # for each READ test, we init RAM with random values
        addr = 4*random.randint(0,SIZE/4)
        ref_data = random.randint(0,0xFFFFFFFF)
        dut.req_i.value = 1
        dut.we_i.value = 0
        dut.add_i.value = addr

        # put the ref in memory
        axi_lite_ram_slave.write(addr, ref_data.to_bytes(4, 'little'))
        await RisingEdge(dut.clk)

        while not dut.r_valid_o == 1:
            # as long as rdata is not flagged as valide, we wait...
            await RisingEdge(dut.clk)
            
        # check that the read is good and that gn_o was raised
        assert dut.r_rdata_o.value == ref_data
        dut.req_i.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # TODO : quickly test what happens if you don't wait for TX to complete and compare
        # a whole ref at the end.

