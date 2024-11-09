import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def lw_control_test(dut):
    # TEST CONTROL SIGNALS FOR LW
    await Timer(1, units="ns")
    dut.op.value = 0b0000011 # I-TYPE
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "01"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def sw_control_test(dut):
    # TEST CONTROL SIGNALS FOR SW
    await Timer(10, units="ns")
    dut.op.value = 0b0100011 # S-TYPE
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "001"
    assert dut.mem_write.value == "1"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "1"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def add_control_test(dut):
    # TEST CONTROL SIGNALS FOR ADD
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b000 # add, sub
    dut.func7.value = 0b0000000 # add
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def and_control_test(dut):
    # TEST CONTROL SIGNALS FOR AND
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b111 # and
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0010"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def or_control_test(dut):
    # TEST CONTROL SIGNALS FOR OR
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b110 # or
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0011"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def beq_control_test(dut):
    # TEST CONTROL SIGNALS FOR BEQ
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b000 # beq
    dut.alu_zero.value = 0b0
    await Timer(1, units="ns")

    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0001"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == "0"

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_zero.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == "1"
    assert dut.second_add_source.value == "0"

@cocotb.test()
async def jal_control_test(dut):
    # TEST CONTROL SIGNALS FOR JAL
    await Timer(10, units="ns")
    dut.op.value = 0b1101111 # J-TYPE
    await Timer(1, units="ns")

    assert dut.imm_source.value == "011"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.branch.value == "0"
    assert dut.jump.value == "1"
    assert dut.pc_source.value == "1"
    assert dut.write_back_source.value == "10"
    assert dut.second_add_source.value == "0"

@cocotb.test()
async def addi_control_test(dut):
    # TEST CONTROL SIGNALS FOR ADDI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b000
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def lui_control_test(dut):
    # TEST CONTROL SIGNALS FOR LUI
    await Timer(10, units="ns")
    dut.op.value = 0b0110111 # U-TYPE (lui)
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.imm_source.value == "100"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.write_back_source.value == "11"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.second_add_source.value == "1"

@cocotb.test()
async def auipc_control_test(dut):
    # TEST CONTROL SIGNALS FOR AUIPC
    await Timer(10, units="ns")
    dut.op.value = 0b0010111 # U-TYPE (auipc)
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.imm_source.value == "100"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.write_back_source.value == "11"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.second_add_source.value == "0"

@cocotb.test()
async def slti_control_test(dut):
    # TEST CONTROL SIGNALS FOR SLTI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b010 # slti
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0101"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def sltiu_control_test(dut):
    # TEST CONTROL SIGNALS FOR SLTIU
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b011 # sltiu
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0111"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def xori_control_test(dut):
    # TEST CONTROL SIGNALS FOR XORI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b100 # xori
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "1000"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

@cocotb.test()
async def slli_control_test(dut):
    # TEST CONTROL SIGNALS FOR SLLI

    # VALID F7
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b001 # slli
    dut.func7.value = 0b0000000
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0100"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

    # INVALID F7
    for _ in range(1000):
        await Timer(1, units="ns")
        dut.op.value = 0b0010011 # I-TYPE (alu)
        dut.func3.value = 0b001 # slli
        dut.func7.value = random.randint(0b0000001,0b1111111)
        await Timer(1, units="ns")

        # Logic block controls
        assert dut.alu_control.value == "0100"
        assert dut.imm_source.value == "000"
        assert dut.mem_write.value == "0"
        assert dut.reg_write.value == "0"
        # Datapath mux sources
        assert dut.alu_source.value == "1"
        assert dut.write_back_source.value == "00"
        assert dut.pc_source.value == "0"

@cocotb.test()
async def srli_control_test(dut):
    # TEST CONTROL SIGNALS FOR SRLI

    # VALID F7
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b101 # srli, srai
    dut.func7.value = 0b0000000 # srli
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "0110"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

    # INVALID VALID F7
    for _ in range(1000):
        await Timer(1, units="ns")
        dut.op.value = 0b0010011 # I-TYPE (alu)
        dut.func3.value = 0b101 # srli, srai
        random_func7 = random.randint(0b0000001,0b1111111)
        # avoid picking the other valid f7 by re-picking
        while(random_func7 == 0b0100000) : random_func7 = random.randint(0b0000001,0b1111111)
        dut.func7.value = random_func7
        await Timer(1, units="ns")

        # Logic block controls
        assert dut.alu_control.value == "0110"
        assert dut.imm_source.value == "000"
        assert dut.mem_write.value == "0"
        assert dut.reg_write.value == "0"
        # Datapath mux sources
        assert dut.alu_source.value == "1"
        assert dut.write_back_source.value == "00"
        assert dut.pc_source.value == "0"

@cocotb.test()
async def srai_control_test(dut):
    # TEST CONTROL SIGNALS FOR SRAI

    # VALID F7
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b101 # srli, srai
    dut.func7.value = 0b0100000 # srai
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.alu_control.value == "1001"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"

    # INVALID VALID F7
    for _ in range(1000):
        await Timer(1, units="ns")
        dut.op.value = 0b0010011 # I-TYPE (alu)
        dut.func3.value = 0b101 # srli, srai
        random_func7 = random.randint(0b0000001,0b1111111)
        # avoid picking the valid f7 by re-picking
        while(random_func7 == 0b0100000) : random_func7 = random.randint(0b0000001,0b1111111)
        dut.func7.value = random_func7
        await Timer(1, units="ns")

        # Logic block controls
        assert dut.alu_control.value == "1001"
        assert dut.imm_source.value == "000"
        assert dut.mem_write.value == "0"
        assert dut.reg_write.value == "0"
        # Datapath mux sources
        assert dut.alu_source.value == "1"
        assert dut.write_back_source.value == "00"
        assert dut.pc_source.value == "0"

@cocotb.test()
async def sub_control_test(dut):
    # TEST CONTROL SIGNALS FOR SUB
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b000 # add, sub
    dut.func7.value = 0b0100000 # sub
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0001"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "00"
    assert dut.pc_source.value == "0"