import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def ls_unit_test(dut):
    word = 0x123ABC00

    # ====
    # SW
    # ====
    dut.f3.value = 0b010
    for offset in range(4):
        dut.alu_result_address.value = word | offset
        await Timer(1, units="ns")
        if offset == 0b00:
            assert dut.byte_enable.value == 0b1111
        else :
            assert dut.byte_enable.value == 0b0000
    
    # ====
    # SB
    # ====
    await Timer(10, units="ns")

    dut.f3.value = 0b000
    for offset in range(4):
        dut.alu_result_address.value = word | offset
        await Timer(1, units="ns")
        if offset == 0b00:
            assert dut.byte_enable.value == 0b0001
        elif offset == 0b01:
            assert dut.byte_enable.value == 0b0010
        elif offset == 0b10:
            assert dut.byte_enable.value == 0b0100
        elif offset == 0b11:
            assert dut.byte_enable.value == 0b1000