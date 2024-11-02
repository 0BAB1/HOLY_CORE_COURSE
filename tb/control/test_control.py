import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def lw_control_test(dut):
    # TEST CONTROL SIGNALS FOR LW
    await Timer(1, units="ns")
    dut.op.value = 0b0000011 # I-TYPE
    await Timer(1, units="ns")
    # Logic block controls
    assert dut.alu_control.value == "000"
    assert dut.imm_source.value == "00"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "1"

@cocotb.test()
async def sw_control_test(dut):
    # TEST CONTROL SIGNALS FOR SW
    await Timer(10, units="ns")
    dut.op.value = 0b0100011 # S-TYPE
    await Timer(1, units="ns")
    assert dut.alu_control.value == "000"
    assert dut.imm_source.value == "01"
    assert dut.mem_write.value == "1"
    assert dut.reg_write.value == "0"
    # Datapath mux sources
    assert dut.alu_source.value == "1"

@cocotb.test()
async def add_control_test(dut):
    # TEST CONTROL SIGNALS FOR ADD
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    # Watch out ! F3 is important here and now !
    dut.func3.value = 0b000
    await Timer(1, units="ns")
    assert dut.alu_control.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "0"