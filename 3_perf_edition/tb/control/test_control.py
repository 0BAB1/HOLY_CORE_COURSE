# CONTROL TESTBENCH
#
# Simple testbench for I/O of the control module
# larger scale tests like unaligned exception behavior
# are test by a larger behavioral test suite (riscof).
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
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

    # declare incoming instruction as valid
    dut.instr_cache_valid.value = 1
    # declare incoming target addresses as aligned
    dut.alu_aligned_addr.value = 0b11
    dut.second_add_aligned_addr.value = 0b11
    dut.jump_to_debug.value = 0b0
    dut.jump_to_debug_exception.value = 0b0
    await Timer(1, units="ns")


# =============================================================================
# BASE INTEGER INSTRUCTION TESTS
# =============================================================================

@cocotb.test()
async def loads_control_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    assert dut.alu_req_valid.value == 0
    await set_unknown(dut)

    await Timer(1, units="ns")
    dut.op.value = 0b0000011  # I-TYPE LOAD
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0000
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 1
    assert dut.reg_write.value == 1
    assert dut.csr_write_enable.value == 0
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b001
    assert dut.pc_source.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def sw_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0100011  # S-TYPE
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0000
    assert dut.imm_source.value == 0b001
    assert dut.mem_write.value == 1
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 1
    assert dut.pc_source.value == 0
    assert dut.mem_read.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def add_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-TYPE
    dut.func3.value = 0b000   # add, sub
    dut.func7.value = 0b0000000  # add
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0000
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.mem_read.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def and_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-TYPE
    dut.func3.value = 0b111   # and
    dut.func7.value = 0b0000000
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0010
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def or_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-TYPE
    dut.func3.value = 0b110   # or
    dut.func7.value = 0b0000000
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0011
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.csr_write_enable.value == 0


@cocotb.test()
async def beq_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b000   # beq
    dut.alu_zero.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b0001
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_zero.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.exception.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def jal_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1101111  # J-TYPE: jal
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b011
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.branch.value == 0
    assert dut.jump.value == 1
    assert dut.pc_source.value == 1
    assert dut.write_back_source.value == 0b010
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def addi_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b000
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0000
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def lui_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110111  # U-TYPE (lui)
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b100
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.write_back_source.value == 0b011
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.second_add_source.value == 0b01
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def auipc_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010111  # U-TYPE (auipc)
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b100
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.write_back_source.value == 0b011
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.alu_req_valid.value == 0
    assert dut.csr_write_enable.value == 0


@cocotb.test()
async def slti_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b010   # slti
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0101
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.csr_write_enable.value == 0


@cocotb.test()
async def sltiu_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b011   # sltiu
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b0111
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.csr_write_enable.value == 0


@cocotb.test()
async def xori_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b100   # xori
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01000
    assert dut.imm_source.value == 0b000
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def slli_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b001   # slli
    dut.func7.value = 0b0000000
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b00100
    assert dut.imm_source.value == 0b000
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def srli_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b101   # srli, srai
    dut.func7.value = 0b0000000  # srli
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b00110
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def srai_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-TYPE (alu)
    dut.func3.value = 0b101   # srli, srai
    dut.func7.value = 0b0100000  # srai
    await Timer(1, units="ns")

    assert dut.alu_control.value == 0b1001
    assert dut.imm_source.value == 0b000
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 1
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def sub_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-TYPE
    dut.func3.value = 0b000   # add, sub
    dut.func7.value = 0b0100000  # sub
    await Timer(1, units="ns")

    assert dut.alu_control.value == 0b0001
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def blt_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b100   # blt
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b0101
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def bne_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b001   # bne
    dut.alu_zero.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b0001
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_zero.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def bge_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b101   # bge
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b0101
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def bltu_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b110   # bltu
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b00111
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def bgeu_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100011  # B-TYPE
    dut.func3.value = 0b111   # bgeu
    dut.alu_last_bit.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b010
    assert dut.alu_control.value == 0b0111
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.alu_source.value == 0
    assert dut.branch.value == 1
    assert dut.pc_source.value == 0
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0

    # Test if branching condition is met
    await Timer(3, units="ns")
    dut.alu_last_bit.value = 0b0
    await Timer(1, units="ns")
    assert dut.pc_source.value == 1
    assert dut.second_add_source.value == 0b00
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def jalr_control_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1100111  # Jump / I-type: jalr
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b000
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 1
    assert dut.branch.value == 0
    assert dut.jump.value == 1
    assert dut.pc_source.value == 1
    assert dut.write_back_source.value == 0b010
    assert dut.second_add_source.value == 0b10
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 0
    assert dut.m_ret.value == 0


@cocotb.test()
async def csr_control_test(dut):
    await set_unknown(dut)

    # with F3 = 0xx (CSRRW)
    await Timer(10, units="ns")
    dut.op.value = 0b1110011  # SYSTEM
    dut.func3.value = 0b001   # CSRRW
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.imm_source.value == 0b101
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 1
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.pc_source.value == 0
    assert dut.write_back_source.value == 0b100
    assert dut.csr_write_enable.value == 1
    assert dut.csr_write_back_source.value == 0
    assert dut.m_ret.value == 0

    # with F3 = 1xx (CSRRWI)
    await Timer(10, units="ns")
    dut.op.value = 0b1110011  # SYSTEM
    dut.func3.value = 0b101   # CSRRWI
    await Timer(1, units="ns")
    assert dut.csr_write_back_source.value == 1
    assert dut.exception.value == 0
    assert dut.m_ret.value == 0


# =============================================================================
# M EXTENSION TESTS
# =============================================================================

@cocotb.test()
async def mul_control_test(dut):
    """Test MUL instruction: rd = (rs1 * rs2)[31:0]"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b000      # MUL
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01010  # ALU_MUL
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def mulh_control_test(dut):
    """Test MULH instruction: rd = (rs1 * rs2)[63:32] (signed × signed)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b001      # MULH
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01011  # ALU_MULH
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def mulhsu_control_test(dut):
    """Test MULHSU instruction: rd = (rs1 * rs2)[63:32] (signed × unsigned)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b010      # MULHSU
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01100  # ALU_MULHSU
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def mulhu_control_test(dut):
    """Test MULHU instruction: rd = (rs1 * rs2)[63:32] (unsigned × unsigned)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b011      # MULHU
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01101  # ALU_MULHU
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.alu_req_valid.value == 1
    assert dut.m_ret.value == 0


@cocotb.test()
async def div_control_test(dut):
    """Test DIV instruction: rd = rs1 / rs2 (signed)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b100      # DIV
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01110  # ALU_DIV
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def divu_control_test(dut):
    """Test DIVU instruction: rd = rs1 / rs2 (unsigned)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b101      # DIVU
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b01111  # ALU_DIVU
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def rem_control_test(dut):
    """Test REM instruction: rd = rs1 % rs2 (signed)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b110      # REM
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b10000  # ALU_REM
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


@cocotb.test()
async def remu_control_test(dut):
    """Test REMU instruction: rd = rs1 % rs2 (unsigned)"""
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b0110011     # R-TYPE
    dut.func3.value = 0b111      # REMU
    dut.func7.value = 0b0000001  # M extension
    await Timer(1, units="ns")

    assert dut.exception.value == 0
    assert dut.alu_control.value == 0b10001  # ALU_REMU
    assert dut.mem_write.value == 0
    assert dut.mem_read.value == 0
    assert dut.reg_write.value == 1
    assert dut.alu_source.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.pc_source.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.m_ret.value == 0
    assert dut.alu_req_valid.value == 1


# =============================================================================
# EXCEPTION AND TRAP TESTS
# =============================================================================

@cocotb.test()
async def ecall_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1110011
    dut.func3.value = 0b000
    dut.instr.value = (0b000000000000 << 20)
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 1
    assert dut.exception_cause.value == 11
    assert dut.m_ret.value == 0
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC


@cocotb.test()
async def ebreak_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1110011
    dut.func3.value = 0b000
    dut.instr.value = (0b000000000001 << 20)
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0
    assert dut.exception.value == 1
    assert dut.exception_cause.value == 3
    assert dut.m_ret.value == 0
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC


@cocotb.test()
async def illegal_instr_test(dut):
    await set_unknown(dut)

    # === 1) Illegal opcode ===
    await Timer(10, units="ns")
    dut.op.value = 0b0000000
    dut.func3.value = 0b000
    dut.instr.value = 0
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
    assert dut.reg_write.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.mem_write.value == 0

    # === 2) Legal opcode but bad func3 ===
    await Timer(10, units="ns")
    dut.op.value = 0b0100011  # S-type
    dut.func3.value = 0b111   # invalid
    dut.instr.value = (0 << 20)
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
    assert dut.reg_write.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.mem_write.value == 0

    # === 3) Legal opcode + func3 but illegal func7 ===
    await Timer(10, units="ns")
    dut.op.value = 0b0110011  # R-type
    dut.func3.value = 0b000   # ADD/SUB
    dut.func7.value = 0b1110111  # Invalid
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
    assert dut.reg_write.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.mem_write.value == 0

    # === 4) Legal opcode + func3 but illegal func7 for shift immediate ===
    await Timer(10, units="ns")
    dut.op.value = 0b0010011  # I-type ALU
    dut.func3.value = 0b101   # SRLI/SRAI
    dut.func7.value = 0b1110111  # Invalid
    dut.trap.value = 0b1
    await Timer(1, units="ns")

    assert dut.exception.value == 1
    assert dut.exception_cause.value == 2
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
    assert dut.reg_write.value == 0
    assert dut.csr_write_enable.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.alu_req_valid.value == 0
    assert dut.mem_write.value == 0


@cocotb.test()
async def simple_trap_request_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.trap.value = 0b1

    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0
    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC


@cocotb.test()
async def stalled_trap_request_test(dut):
    await set_unknown(dut)
    dut.rst_n.value = 1

    await Timer(10, units="ns")
    dut.trap.value = 0b1
    dut.stall.value = 0b1

    assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0

    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    dut.trap.value = 0b0
    await Timer(1, units="ns")

    for _ in range(50):
        assert dut.trap_pending.value == 1
        assert dut.pc_source.value == 0b010  # SOURCE_PC_MTVEC
        assert dut.mem_read.value == 0
        assert dut.mem_write.value == 0
        assert dut.reg_write.value == 0
        assert dut.branch.value == 0
        assert dut.jump.value == 0
        assert dut.write_back_source.value == 0b000
        assert dut.csr_write_enable.value == 0
        await RisingEdge(dut.clk)

    dut.stall.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    assert dut.trap_pending.value == 0


@cocotb.test()
async def simple_return_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1110011  # system OPCODE
    dut.func3.value = 0b000   # system F3
    dut.instr.value = 0b00110000001000000000000001110011  # mret
    await Timer(1, units="ns")

    assert dut.m_ret.value == 1
    assert dut.pc_source.value == 0b011  # SOURCE_PC_MEPC
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0


@cocotb.test()
async def simple_debug_return_test(dut):
    await set_unknown(dut)

    await Timer(10, units="ns")
    dut.op.value = 0b1110011  # system OPCODE
    dut.func3.value = 0b000   # system F3
    dut.instr.value = 0b01111011001000000000000001110011  # dret
    await Timer(1, units="ns")

    assert dut.m_ret.value == 0
    assert dut.d_ret.value == 1
    assert dut.pc_source.value == 0b100  # SOURCE_PC_DPC
    assert dut.mem_read.value == 0
    assert dut.mem_write.value == 0
    assert dut.reg_write.value == 0
    assert dut.branch.value == 0
    assert dut.jump.value == 0
    assert dut.write_back_source.value == 0b000
    assert dut.csr_write_enable.value == 0