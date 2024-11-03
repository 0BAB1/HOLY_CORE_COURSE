import cocotb
from cocotb.triggers import Timer
import random
import numpy as np

@cocotb.test()
async def signext_i_type_test(dut):
    # TEST POSITIVE IMM = 123 WITH SOURCE = 0
    imm = 0b000001111011 #123
    imm <<= 13 # leave "room" for ramdom junk
    source = 0b00
    # 25 bits sent to sign extend contains data before that will be ignred (rd, f3,..)
    # masked to leave room for imm "test payload"
    random_junk = 0b000000000000_1010101010101 
    raw_data = random_junk | imm
    await Timer(1, units="ns")
    dut.raw_src.value = raw_data
    dut.imm_source.value = source
    await Timer(1, units="ns") # let it propagate ...
    assert dut.immediate.value == "00000000000000000000000001111011", f"expected 00000000000000000000000001111011, got {dut.immediate.value}"
    assert int(dut.immediate.value) == 123

    # TEST Negative IMM = -42 WITH SOURCE = 0
    imm = 0b111111010110 #-42
    imm <<= 13 # leave "room" for ramdom junk
    source = 0b00
    # 25 bits sent to sign extend contains data before that will be ignred (rd, f3,..)
    # masked to leave room for imm "test payload"
    random_junk = 0b000000000000_1010101010101 
    raw_data = random_junk | imm
    await Timer(1, units="ns")
    dut.raw_src.value = raw_data
    dut.imm_source.value = source
    await Timer(1, units="ns") # let it propagate ...
    assert dut.immediate.value == "11111111111111111111111111010110", f"expected 11111111111111111111111111010110, got {dut.immediate.value}"
    # Python interprets int as uint. we sub 1<<32 as int to get corresponding negative value
    assert int(dut.immediate.value) - (1 << 32)  == -42

@cocotb.test()
async def signext_s_type_test(dut):
    # 100 randomized tests
    for _ in range(100):
        # TEST POSITIVE IMM
        await Timer(100, units="ns")
        imm = random.randint(0,0b01111111111) 
        imm_11_5 = imm >> 5
        imm_4_0 = imm & 0b000000011111
        raw_data = (imm_11_5 << 18) | (imm_4_0) # the 25 bits of data
        source = 0b01
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        assert int(dut.immediate.value) == imm

        # TEST Negative IMM
        # Get a random 12 bits UINT and gets its base 10 neg value by - (1 << 12)
        imm = random.randint(0b100000000000,0b111111111111) 
        imm_11_5 = imm >> 5
        imm_4_0 = imm & 0b000000011111
        raw_data = (imm_11_5 << 18) | (imm_4_0) # the 25 bits of data
        source = 0b01
        await Timer(1, units="ns")
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        # print(bin(imm),dut.raw_src.value)
        # print(int(dut.immediate.value), imm)
        assert int(dut.immediate.value) - (1 << 32) == imm - (1 << 12)

@cocotb.test()
async def signext_b_type_test(dut):
    # 100 randomized tests
    for _ in range(100):
        # TEST POSITIVE IMM
        await Timer(100, units="ns")
        imm = random.randint(0,0b011111111111) 
        imm <<= 1 # 13 bits signed imm ending with a 0
        imm_12 = (imm & 0b1000000000000) >> 12 # 0 for now (positive)
        imm_11 = (imm & 0b0100000000000) >> 11
        imm_10_5 = (imm & 0b0011111100000) >> 5
        imm_4_1 = (imm & 0b0000000011110) >> 1
        raw_data = (imm_12 << 24) | (imm_11 << 0) | (imm_10_5 << 18) | (imm_4_1 << 1)
        source = 0b10
        await Timer(1, units="ns")
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        assert int(dut.immediate.value) == imm 

        # TEST NEGATIVE IMM
        await Timer(100, units="ns")
        imm = random.randint(0b100000000000,0b111111111111)
        imm <<= 1 # 13 bits signed imm ending with a 0
        imm_12 = (imm & 0b1000000000000) >> 12 # 1 (negative)
        imm_11 = (imm & 0b0100000000000) >> 11
        imm_10_5 = (imm & 0b0011111100000) >> 5
        imm_4_1 = (imm & 0b0000000011110) >> 1
        raw_data = (imm_12 << 24) | (imm_11 << 0) | (imm_10_5 << 18) | (imm_4_1 << 1)
        source = 0b10
        await Timer(1, units="ns")
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        assert int(dut.immediate.value) - (1 << 32) == imm - (1 << 13)

@cocotb.test()
async def signext_j_type_test(dut):
    # 100 randomized tests
    for _ in range(100):
        # TEST POSITIVE IMM
        await Timer(100, units="ns")
        imm = random.randint(0,0b01111111111111111111) 
        imm <<= 1 # 21 bits signed imm ending with a 0
        imm_20 =     (imm & 0b100000000000000000000) >> 20
        imm_19_12 =  (imm & 0b011111111000000000000) >> 12
        imm_11 =     (imm & 0b000000000100000000000) >> 11
        imm_10_1 =   (imm & 0b000000000011111111110) >> 1
        raw_data =  (imm_20 << 24) | (imm_19_12 << 5) | (imm_11 << 13) | (imm_10_1 << 14)
        source = 0b11
        await Timer(1, units="ns")
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        assert int(dut.immediate.value) == imm

        # TEST NEGATIVE IMM
        await Timer(100, units="ns")
        imm = random.randint(0b10000000000000000000,0b11111111111111111111) 
        imm <<= 1 # 21 bits signed imm ending with a 0
        imm_20 =     (imm & 0b100000000000000000000) >> 20
        imm_19_12 =  (imm & 0b011111111000000000000) >> 12
        imm_11 =     (imm & 0b000000000100000000000) >> 11
        imm_10_1 =   (imm & 0b000000000011111111110) >> 1
        raw_data =  (imm_20 << 24) | (imm_19_12 << 5) | (imm_11 << 13) | (imm_10_1 << 14)
        source = 0b11
        await Timer(1, units="ns")
        dut.raw_src.value = raw_data
        dut.imm_source.value = source
        await Timer(1, units="ns") # let it propagate ...
        assert int(dut.immediate.value) - (1 << 32) == imm - (1 << 21)