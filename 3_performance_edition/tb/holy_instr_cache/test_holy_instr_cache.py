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
CPU_PERIOD = 10
TEST_NUM = 10_000
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

   
    # TEST THE CACHED DATA
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

    # ================================
    # Read random data
    # ================================
    
    for _ in range(TEST_NUM):
        test_addr = random.randint(0, SIZE >> 2)
        test_addr = test_addr << 2

        dut.cpu_address.value = test_addr
        await Timer(1, units="ns")

        while not dut.cpu_instr_valid.value == 1:
            await RisingEdge(dut.clk)
            await Timer(1, units="ns")
        
        read_out = dut.cpu_read_enable.value
        assert read_out == mem_golden_ref[test_addr >> 2]

    # ================================
    # Write random data
    # ================================


    # ================================
    # Read random data
    # ================================