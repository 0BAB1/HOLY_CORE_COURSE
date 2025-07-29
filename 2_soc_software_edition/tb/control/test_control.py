# CONTROL TESTBECH
#
# Simple testbench for I/O of the control module
# larger scale tests like unaligned exception behavior
# are test by a larger bahavioral test suite (riscof).
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random
from cocotb.binary import BinaryValue

@cocotb.coroutine
async def set_unknown(dut):
    # Set all input to unknown before each test
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await Timer(1, units="ns")
    dut.op.value = BinaryValue("XXXXXXX")
    dut.func3.value = BinaryValue("XXX")
    dut.func7.value = BinaryValue("XXXXXXX")
    dut.alu_zero.value = BinaryValue("X")
    dut.alu_last_bit.value = BinaryValue("X")

    # declare incomming instruction as valid
    dut.instr_cache_valid.value = 1
    # declare incomming target addresses as aligned
    # (packed type with 2x flags)
    dut.alu_aligned_addr.value = 0b11           
    dut.second_add_aligned_addr.value = 0b11
    await Timer(1, units="ns")

@cocotb.test()
async def loads_control_test(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR LW
    await Timer(1, units="ns")
    dut.op.value = 0b0000011 # I-TYPE
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "1"
    assert dut.reg_write.value == "1"
    assert dut.csr_write_enable == "0"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "001"
    assert dut.pc_source.value == 0
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def sw_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SW
    await Timer(10, units="ns")
    dut.op.value = 0b0100011 # S-TYPE
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "001"
    assert dut.mem_write.value == "1"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "1"
    assert dut.pc_source.value == 0
    assert dut.mem_read.value == "0"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def add_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR ADD
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b000 # add, sub
    dut.func7.value = 0b0000000 # add
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == "0000"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.mem_read.value == "0"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def and_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR AND
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b111 # and
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == "0010"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def or_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR OR
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b110 # or
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == "0011"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"

@cocotb.test()
async def beq_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BEQ
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b000 # beq
    dut.alu_zero.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0001"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_zero.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def jal_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR JAL
    await Timer(10, units="ns")
    dut.op.value = 0b1101111 # J-TYPE : jalr
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "011"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.branch.value == "0"
    assert dut.jump.value == "1"
    assert dut.pc_source.value == 1
    assert dut.write_back_source.value == "010"
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def addi_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR ADDI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b000
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0000"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def lui_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR LUI
    await Timer(10, units="ns")
    dut.op.value = 0b0110111 # U-TYPE (lui)
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.imm_source.value == "100"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.write_back_source.value == "011"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.second_add_source.value == "01"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def auipc_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR AUIPC
    await Timer(10, units="ns")
    dut.op.value = 0b0010111 # U-TYPE (auipc)
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.imm_source.value == "100"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.write_back_source.value == "011"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"

@cocotb.test()
async def slti_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SLTI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b010 # slti
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0101"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"

@cocotb.test()
async def sltiu_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SLTIU
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b011 # sltiu
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0111"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"

@cocotb.test()
async def xori_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR XORI
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b100 # xori
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "1000"
    assert dut.imm_source.value == "000"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def slli_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SLLI

    # VALID F7
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b001 # slli
    dut.func7.value = 0b0000000
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0100"
    assert dut.imm_source.value == "000"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def srli_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SRLI

    # VALID F7
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-TYPE (alu)
    dut.func3.value = 0b101 # srli, srai
    dut.func7.value = 0b0000000 # srli
    await Timer(1, units="ns")

    # Logic block controls
    assert dut.exception.value == 0
    assert dut.alu_control.value == "0110"
    assert dut.imm_source.value == "000"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def srai_control_test(dut):
    await set_unknown(dut)
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
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    # Datapath mux sources
    assert dut.alu_source.value == "1"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def sub_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR SUB
    await Timer(10, units="ns")
    dut.op.value = 0b0110011 # R-TYPE
    dut.func3.value = 0b000 # add, sub
    dut.func7.value = 0b0100000 # sub
    await Timer(1, units="ns")

    assert dut.alu_control.value == "0001"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.alu_source.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def blt_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BLT (underlying logic same as BEQ)
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b100 # blt
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0101"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def bne_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BNE
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b001 # bne
    dut.alu_zero.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0001"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_zero.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def bge_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BGE
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b101 # bge
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0101"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def bltu_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BNE
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b110 # bltu
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0111"
    assert dut.mem_write.value == "0"
    assert dut.mem_read.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def bgeu_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR BNE
    await Timer(10, units="ns")
    dut.op.value = 0b1100011 # B-TYPE
    dut.func3.value = 0b111 # bgeu
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "010"
    assert dut.alu_control.value == "0111"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.alu_source.value == "0"
    assert dut.branch.value == "1"
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == "00"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def jalr_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR JALR
    await Timer(10, units="ns")
    dut.op.value = 0b1100111 # Jump / I-type : jalr 
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "000"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.branch.value == "0"
    assert dut.jump.value == "1"
    assert dut.pc_source.value == 1
    assert dut.write_back_source.value == "010"
    assert dut.second_add_source.value == "10"
    assert dut.csr_write_enable == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

@cocotb.test()
async def csr_control_test(dut):
    await set_unknown(dut)
    # TEST CONTROL SIGNALS FOR CSR Instructions

    # with F3 = 0xx
    await Timer(10, units="ns")
    dut.op.value = 0b1110011 # SYSTEM
    dut.func3.value = 0b001 # CSRRW
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == "101"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "1"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.pc_source.value == 0
    assert dut.write_back_source.value == "100"
    assert dut.csr_write_enable == "1"
    assert dut.csr_write_back_source.value == "0"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0

    # with F3 = 0xx
    await Timer(10, units="ns")
    dut.op.value = 0b1110011 # SYSTEM
    dut.func3.value = 0b101 # CSRRWI
    await Timer(1, units="ns")
    assert dut.csr_write_back_source.value == "1"
    # no exception nor return !
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def ecall_test(dut):
    await set_unknown(dut)

    # ecall
    await Timer(10, units="ns")
    dut.op.value = 0b1110011
    dut.func3.value = 0b000
    dut.instr.value = (0b000000000000 << 20)  # upper immediate field [31:20] = 0
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    # assert dut.imm_source.value == "101"
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.csr_write_enable == "0"
    # assert dut.csr_write_back_source.value == "0"
    # exception for ecall
    assert dut.exception.value == 1
    assert dut.exception_cause.value == 11
    assert dut.m_ret.value == 0
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

@cocotb.test()
async def ebreak_test(dut):
    await set_unknown(dut)

    # ebreak
    await Timer(10, units="ns")
    dut.op.value = 0b1110011  # SYSTEM opcode
    dut.func3.value = 0b000   # SYSTEM func3
    dut.instr.value = (0b000000000001 << 20)
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    # Assetions
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.csr_write_enable.value == "0"
    # exception for ebreak
    assert dut.exception.value == 1
    assert dut.exception_cause.value == 3  # EBREAK
    assert dut.m_ret.value == 0
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

@cocotb.test()
async def illegal_instr_test(dut):
    await set_unknown(dut)

    # === 1) Illegal opcode ===
    await Timer(10, units="ns")
    dut.op.value = 0b0000000  # INVILD !
    dut.func3.value = 0b000
    dut.instr.value = 0
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2  # ILLEGAL CODE
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC
    # should not alter cpu state !
    assert dut.reg_write.value == "0"
    assert dut.csr_write_enable.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.mem_write.value == "0"

    # === 2) Legal opcode but bad func3 ===
    await Timer(10, units="ns")
    dut.op.value = 0b100011  # S-type
    dut.func3.value = 0b111 # invalid !
    dut.instr.value = (0 << 20)
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

    # should not alter cpu state !
    assert dut.reg_write.value == "0"
    assert dut.csr_write_enable.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.mem_write.value == "0"

    # Should not assert here yet — next covers func7 check

    # === 3) Legal opcode + func3 but illegal func7 ===
    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-type
    dut.func3.value = 0b000   # ADD/SUB
    dut.func7.value = 0b1110111 # Invalid !
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

    # should not alter cpu state !
    assert dut.reg_write.value == "0"
    assert dut.csr_write_enable.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.mem_write.value == "0"

    # === 4) Legal opcode + func3 but illegal func7 for shift immediate ===
    await Timer(10, units="ns")
    dut.op.value = 0b0010011 # I-type ALU
    dut.func3.value = 0b101   # SRLI/SRAI
    dut.func7.value = 0b1110111 # Invalid !
    # trap is high, set with comb logic by csr_file
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

    # should not alter cpu state !
    assert dut.reg_write.value == "0"
    assert dut.csr_write_enable.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.mem_write.value == "0"

@cocotb.test()
async def simple_trap_request_test(dut):
    await set_unknown(dut)

    # We recieve a trap request
    await Timer(10, units="ns")
    dut.trap.value = 0b1

    # Fetched instruction will not be executed !
    # CPU satte should be preserved !
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.csr_write_enable.value == "0"
    # Should output SOURCE_PC_MTVEC as the next pc source
    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC

@cocotb.test()
async def stalled_trap_request_test(dut):
    # Trap requested but cpu is talled, meaning we cannot
    # trap right away !
    await set_unknown(dut)
    # this test will run assetrion on registers: realease rest !
    dut.rst_n.value = 1

    # We recieve a trap request, and cpu stalls
    await Timer(10, units="ns")
    dut.trap.value = 0b1
    dut.stall.value = 0b1

    assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC
    # Fetched instruction will not be executed !
    # CPU state should be preserved !
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.csr_write_enable.value == "0"

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    
    # now trap is deasseted. trap_peding should
    # keep track of this unexecuted trap request
    dut.trap.value = 0b0
    await Timer(1, units="ns")

    for _ in range(50):
        # trap still pending, cpu stalling
        assert dut.trap_pending.value == 1
        assert dut.pc_source.value == 0b10 # SOURCE_PC_MTVEC
        # CPU state should be preserved !
        assert dut.mem_read.value == "0"
        assert dut.mem_write.value == "0"
        assert dut.reg_write.value == "0"
        assert dut.branch.value == "0"
        assert dut.jump.value == "0"
        assert dut.write_back_source.value == "000"
        assert dut.csr_write_enable.value == "0"
        await RisingEdge(dut.clk)

    # not stalling anymore
    dut.stall.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    
    assert dut.trap_pending.value == 0

@cocotb.test()
async def simple_return_test(dut):
    # reminder : mret
    # 0011000 | 00010 | 00000 | 000 | 00000 | 1110011
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1110011 # system OPCODE
    dut.func3.value = 0b000  # system F3
    dut.instr.value = (
        0b00110000001000000000000001110011
    ) # mret
    await Timer(1, units="ns")


    assert dut.m_ret.value == 1
    assert dut.pc_source.value == 0b11 # SOURCE_PC_MEPC

    # CPU state should be preserved !
    assert dut.mem_read.value == "0"
    assert dut.mem_write.value == "0"
    assert dut.reg_write.value == "0"
    assert dut.branch.value == "0"
    assert dut.jump.value == "0"
    assert dut.write_back_source.value == "000"
    assert dut.csr_write_enable.value == "0"
    