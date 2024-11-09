import cocotb
from cocotb.triggers import Timer
import random

def binary_to_hex(bin_str):
    # Convert binary string to hexadecimal
    hex_str = hex(int(str(bin_str), 2))[2:]
    hex_str = hex_str.zfill(8)
    return hex_str.upper()

@cocotb.test()
async def add_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0000
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2
        # We mask expected to not take account of overflows
        expected = (src1 + src2) & 0xFFFFFFFF
        # Await 1 ns for the infos to propagate
        await Timer(1, units="ns")
        assert int(dut.alu_result.value) == expected

@cocotb.test()
async def and_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0010
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2
        expected = src1 & src2
        # Await 1 ns for the infos to propagate
        await Timer(1, units="ns")
        assert int(dut.alu_result.value) == expected       

@cocotb.test()
async def or_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0011
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2
        expected = src1 | src2
        # Await 1 ns for the infos to propagate
        await Timer(1, units="ns")
        assert int(dut.alu_result.value) == expected   

@cocotb.test()
async def sub_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0001
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        # src1 = random.randint(0,0xFF)
        # src2 = random.randint(0,0xFF)
        # print(bin(src1)[2:].zfill(8))
        # print(bin(src2)[2:].zfill(8))
        # print(bin(src1 - src2)[2:].zfill(8))
        dut.src1.value = src1
        dut.src2.value = src2
        expected = (src1 - src2) & 0xFFFFFFFF

        await Timer(1, units="ns")

        assert str(dut.alu_result.value) == bin(expected)[2:].zfill(32)
        assert binary_to_hex(dut.alu_result.value) == hex(expected)[2:].zfill(8).upper()
        assert int(str(dut.alu_result.value),2) == expected

@cocotb.test()
async def slt_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0101
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2

        await Timer(1, units="ns")

        # if scr1 pos, src2 pos
        if src1 >> 31 == 0 and src2 >> 31 == 0:
            expected = int(src1 < src2)
        # if scr1 pos, src2 neg
        elif src1 >> 31 == 0 and src2 >> 31 == 1:
            expected = int(src1 < (src2 - (1<<32)))
        # if scr1 neg, src2 pos
        elif src1 >> 31 == 1 and src2 >> 31 == 0:
            expected = int((src1 - (1<<32)) < src2)
        # if scr1 neg, src2 neg
        elif src1 >> 31 == 1 and src2 >> 31 == 1:
            expected = int((src1 - (1<<32)) < (src2 - (1<<32)))

        assert int(dut.alu_result.value) == expected
        assert dut.alu_result.value == 31*"0" + str(int(dut.alu_result.value))

@cocotb.test()
async def sltu_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0111
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2

        await Timer(1, units="ns")
        expected = int(src1 < src2)

        assert dut.alu_result.value == 31*"0" + str(int(dut.alu_result.value))

@cocotb.test()
async def xor_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b1000 #xor
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        dut.src2.value = src2

        await Timer(1, units="ns")
        expected = src1 ^ src2

        assert int(dut.alu_result.value) ==  int(expected)

@cocotb.test()
async def sll_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0100 #sll
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        dut.src1.value = src1
        shamt = src2 & 0b11111
        dut.src2.value = shamt

        await Timer(1, units="ns")
        expected = (src1 << shamt) & 0xFFFFFFFF

        assert int(dut.alu_result.value) ==  int(expected)

@cocotb.test()
async def srl_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0110 #srl
    for _ in range(1000):
        src1 = random.randint(0,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF)
        # pyhton only perfomrs sra
        # but here, pyhton interprets number as non-signed by default, meaning the right shift will
        # unconditionally fill upper bits with 0s and we can pass the test like this :
        dut.src1.value = src1
        shamt = src2 & 0b11111
        dut.src2.value = shamt

        await Timer(1, units="ns")
        expected = (src1 >> shamt) & 0xFFFFFFFF

        assert int(dut.alu_result.value) ==  int(expected)

@cocotb.test()
async def sra_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b1001 #sra
    for _ in range(1000):
        # pyhton only perfomrs sra
        # We have to hint python of the sign so we disociate signed and unsigned

        # UNSIGNED TESTS
        src1 = random.randint(0,0x7FFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF) #shamt can be whatever
        dut.src1.value = src1
        shamt = src2 & 0b11111
        dut.src2.value = shamt

        await Timer(1, units="ns")
        expected = (src1 >> shamt) & 0xFFFFFFFF

        assert int(dut.alu_result.value) ==  int(expected)

        # SIGNED TESTS
        src1 = random.randint(0x80000000,0xFFFFFFFF)
        src2 = random.randint(0,0xFFFFFFFF) #shamt can be whatever
        dut.src1.value = src1
        shamt = src2 & 0b11111
        dut.src2.value = shamt

        await Timer(1, units="ns")
        # We perform an - 1<<32 to get the negative value for python and then apply the sra.
        # We then mash on 32 bits to get the raw bits back to compare
        expected = ( (src1 - (1<<32)) >> shamt) & 0xFFFFFFFF

        assert binary_to_hex(dut.alu_result.value) ==  hex(expected)[2:].upper()
        assert int(dut.alu_result.value) ==  expected

@cocotb.test()
async def zero_test(dut):
    await Timer(1, units="ns")
    dut.alu_control.value = 0b0000
    dut.src1.value = 123
    dut.src2.value = -123
    await Timer(1, units="ns")
    print(int(dut.alu_result.value))
    assert int(dut.zero.value) == 1
    assert int(dut.alu_result.value) == 0