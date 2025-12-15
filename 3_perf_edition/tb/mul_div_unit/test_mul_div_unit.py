# MDU TESTBENCH
#
# Tests for Multiply/Divide Unit with handshake protocol
#
# BRH 12/25

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# MDU control encodings (matches mdu_control_t)
ALU_MUL    = 0b01010
ALU_MULH   = 0b01011
ALU_MULHSU = 0b01100
ALU_MULHU  = 0b01101
ALU_DIV    = 0b01110
ALU_DIVU   = 0b01111
ALU_REM    = 0b10000
ALU_REMU   = 0b10001

# MDU states
ALU_IDLE = 0
ALU_BUSY = 1
ALU_DONE = 2


def to_signed_32(val):
    """Convert unsigned 32-bit value to signed Python int"""
    if val >= 0x80000000:
        return val - 0x100000000
    return val


def to_unsigned_32(val):
    """Convert signed Python int to unsigned 32-bit value"""
    return val & 0xFFFFFFFF


async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.req_valid.value = 0
    dut.res_ack.value = 0
    dut.src1.value = 0
    dut.src2.value = 0
    dut.mdu_control.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def mdu_operation(dut, src1, src2, control):
    """
    Perform an MDU operation with full handshake.
    Returns the result.
    """
    # Setup operands and assert request
    dut.src1.value = src1
    dut.src2.value = src2
    dut.mdu_control.value = control
    dut.req_valid.value = 1

    await RisingEdge(dut.clk)

    # Deassert req_valid after one cycle
    dut.req_valid.value = 0

    # Wait for res_valid
    timeout = 0
    while int(dut.res_valid.value) == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise RuntimeError("MDU timeout waiting for res_valid")

    # Capture result
    result = int(dut.mdu_result.value)

    # Acknowledge result
    dut.res_ack.value = 1
    await RisingEdge(dut.clk)
    dut.res_ack.value = 0
    await RisingEdge(dut.clk)

    # Verify back to IDLE
    assert int(dut.state.value) == ALU_IDLE, "MDU did not return to IDLE after ack"

    return result


# =============================================================================
# MULTIPLICATION TESTS
# =============================================================================

@cocotb.test()
async def mul_basic_test(dut):
    """MUL: Basic multiplication tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    # Simple cases
    test_cases = [
        (0, 0, 0),
        (1, 1, 1),
        (2, 3, 6),
        (0x1000, 0x1000, 0x01000000),
        (0xFFFFFFFF, 1, 0xFFFFFFFF),
        (0xFFFFFFFF, 0, 0),
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_MUL)
        assert result == expected, f"MUL: {src1} * {src2} = {expected}, got {result}"


@cocotb.test()
async def mul_random_test(dut):
    """MUL: Random multiplication tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(200):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(0, 0xFFFFFFFF)
        expected = (src1 * src2) & 0xFFFFFFFF

        result = await mdu_operation(dut, src1, src2, ALU_MUL)
        assert result == expected, f"MUL: {src1} * {src2} = {expected}, got {result}"


@cocotb.test()
async def mulh_test(dut):
    """MULH: Upper 32 bits of signed × signed"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(200):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(0, 0xFFFFFFFF)

        src1_s = to_signed_32(src1)
        src2_s = to_signed_32(src2)
        product = src1_s * src2_s
        expected = (product >> 32) & 0xFFFFFFFF

        result = await mdu_operation(dut, src1, src2, ALU_MULH)
        assert result == expected, f"MULH: {src1_s} * {src2_s}, upper = {expected}, got {result}"


@cocotb.test()
async def mulhsu_test(dut):
    """MULHSU: Upper 32 bits of signed × unsigned"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(200):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(0, 0xFFFFFFFF)

        src1_s = to_signed_32(src1)
        product = src1_s * src2
        expected = (product >> 32) & 0xFFFFFFFF

        result = await mdu_operation(dut, src1, src2, ALU_MULHSU)
        assert result == expected, f"MULHSU: {src1_s} * {src2}, upper = {expected}, got {result}"


@cocotb.test()
async def mulhu_test(dut):
    """MULHU: Upper 32 bits of unsigned × unsigned"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(200):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(0, 0xFFFFFFFF)

        product = src1 * src2
        expected = (product >> 32) & 0xFFFFFFFF

        result = await mdu_operation(dut, src1, src2, ALU_MULHU)
        assert result == expected, f"MULHU: {src1} * {src2}, upper = {expected}, got {result}"


# =============================================================================
# DIVISION TESTS
# =============================================================================

@cocotb.test()
async def div_basic_test(dut):
    """DIV: Basic signed division tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    test_cases = [
        (10, 3, 3),
        (100, 10, 10),
        (0xFFFFFFFF, 0xFFFFFFFF, 1),  # -1 / -1 = 1
        (0x80000000, 2, 0xC0000000),  # INT_MIN / 2 = INT_MIN/2
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_DIV)
        assert result == expected, f"DIV: {src1} / {src2} = {expected}, got {result}"


@cocotb.test()
async def div_random_test(dut):
    """DIV: Random signed division tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(100):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(1, 0xFFFFFFFF)  # Avoid zero

        src1_s = to_signed_32(src1)
        src2_s = to_signed_32(src2)

        # Skip overflow case (tested separately)
        if src1_s == -0x80000000 and src2_s == -1:
            continue

        # Python truncates toward negative infinity, RISC-V toward zero
        quotient = int(src1_s / src2_s)
        expected = to_unsigned_32(quotient)

        result = await mdu_operation(dut, src1, src2, ALU_DIV)
        assert result == expected, f"DIV: {src1_s} / {src2_s} = {quotient}, expected {expected}, got {result}"


@cocotb.test()
async def div_by_zero_test(dut):
    """DIV: Division by zero returns -1"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(20):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = 0

        result = await mdu_operation(dut, src1, src2, ALU_DIV)
        assert result == 0xFFFFFFFF, f"DIV by zero: expected 0xFFFFFFFF, got {hex(result)}"


@cocotb.test()
async def div_overflow_test(dut):
    """DIV: INT_MIN / -1 returns INT_MIN"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    src1 = 0x80000000  # INT_MIN
    src2 = 0xFFFFFFFF  # -1

    result = await mdu_operation(dut, src1, src2, ALU_DIV)
    assert result == 0x80000000, f"DIV overflow: expected 0x80000000, got {hex(result)}"


@cocotb.test()
async def divu_basic_test(dut):
    """DIVU: Basic unsigned division tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    test_cases = [
        (10, 3, 3),
        (100, 10, 10),
        (0xFFFFFFFF, 1, 0xFFFFFFFF),
        (0xFFFFFFFF, 0xFFFFFFFF, 1),
        (0x80000000, 2, 0x40000000),
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_DIVU)
        assert result == expected, f"DIVU: {src1} / {src2} = {expected}, got {result}"


@cocotb.test()
async def divu_random_test(dut):
    """DIVU: Random unsigned division tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(100):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(1, 0xFFFFFFFF)

        expected = src1 // src2

        result = await mdu_operation(dut, src1, src2, ALU_DIVU)
        assert result == expected, f"DIVU: {src1} / {src2} = {expected}, got {result}"


@cocotb.test()
async def divu_by_zero_test(dut):
    """DIVU: Division by zero returns 0xFFFFFFFF"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(20):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = 0

        result = await mdu_operation(dut, src1, src2, ALU_DIVU)
        assert result == 0xFFFFFFFF, f"DIVU by zero: expected 0xFFFFFFFF, got {hex(result)}"


# =============================================================================
# REMAINDER TESTS
# =============================================================================

@cocotb.test()
async def rem_basic_test(dut):
    """REM: Basic signed remainder tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    test_cases = [
        (10, 3, 1),
        (100, 10, 0),
        (7, 4, 3),
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_REM)
        assert result == expected, f"REM: {src1} % {src2} = {expected}, got {result}"


@cocotb.test()
async def rem_signed_test(dut):
    """REM: Signed remainder with negative operands"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    # Test cases: (src1, src2, expected_remainder)
    # RISC-V: remainder has sign of dividend
    test_cases = [
        (to_unsigned_32(-10), 3, to_unsigned_32(-1)),       # -10 % 3 = -1
        (10, to_unsigned_32(-3), 1),                        # 10 % -3 = 1
        (to_unsigned_32(-10), to_unsigned_32(-3), to_unsigned_32(-1)),  # -10 % -3 = -1
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_REM)
        assert result == expected, f"REM: {to_signed_32(src1)} % {to_signed_32(src2)} = {to_signed_32(expected)}, got {to_signed_32(result)}"


@cocotb.test()
async def rem_random_test(dut):
    """REM: Random signed remainder tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(100):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(1, 0xFFFFFFFF)

        src1_s = to_signed_32(src1)
        src2_s = to_signed_32(src2)

        # Skip overflow case
        if src1_s == -0x80000000 and src2_s == -1:
            continue

        # RISC-V remainder: a - (a/b)*b with truncation toward zero
        quotient = int(src1_s / src2_s)
        remainder = src1_s - quotient * src2_s
        expected = to_unsigned_32(remainder)

        result = await mdu_operation(dut, src1, src2, ALU_REM)
        assert result == expected, f"REM: {src1_s} % {src2_s} = {remainder}, expected {expected}, got {result}"


@cocotb.test()
async def rem_by_zero_test(dut):
    """REM: Remainder by zero returns dividend"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(20):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = 0

        result = await mdu_operation(dut, src1, src2, ALU_REM)
        assert result == src1, f"REM by zero: expected {src1}, got {result}"


@cocotb.test()
async def rem_overflow_test(dut):
    """REM: INT_MIN % -1 returns 0"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    src1 = 0x80000000  # INT_MIN
    src2 = 0xFFFFFFFF  # -1

    result = await mdu_operation(dut, src1, src2, ALU_REM)
    assert result == 0, f"REM overflow: expected 0, got {result}"


@cocotb.test()
async def remu_basic_test(dut):
    """REMU: Basic unsigned remainder tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    test_cases = [
        (10, 3, 1),
        (100, 10, 0),
        (0xFFFFFFFF, 0x10000000, 0x0FFFFFFF),
    ]

    for src1, src2, expected in test_cases:
        result = await mdu_operation(dut, src1, src2, ALU_REMU)
        assert result == expected, f"REMU: {src1} % {src2} = {expected}, got {result}"


@cocotb.test()
async def remu_random_test(dut):
    """REMU: Random unsigned remainder tests"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(100):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = random.randint(1, 0xFFFFFFFF)

        expected = src1 % src2

        result = await mdu_operation(dut, src1, src2, ALU_REMU)
        assert result == expected, f"REMU: {src1} % {src2} = {expected}, got {result}"


@cocotb.test()
async def remu_by_zero_test(dut):
    """REMU: Remainder by zero returns dividend"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    for _ in range(20):
        src1 = random.randint(0, 0xFFFFFFFF)
        src2 = 0

        result = await mdu_operation(dut, src1, src2, ALU_REMU)
        assert result == src1, f"REMU by zero: expected {src1}, got {result}"

# =============================================================================
# HANDSHAKE / TIMING TESTS
# =============================================================================

@cocotb.test()
async def mul_single_cycle_test(dut):
    """Verify MUL completes in minimal cycles (IDLE -> DONE)"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    dut.src1.value = 7
    dut.src2.value = 6
    dut.mdu_control.value = ALU_MUL
    dut.req_valid.value = 1

    await RisingEdge(dut.clk)
    dut.req_valid.value = 0

    # Should be in DONE state after one cycle
    await RisingEdge(dut.clk)
    assert int(dut.state.value) == ALU_DONE, "MUL should reach DONE in one cycle"
    assert int(dut.res_valid.value) == 1, "res_valid should be high"
    assert int(dut.mdu_result.value) == 42, "7 * 6 = 42"

    # Acknowledge
    dut.res_ack.value = 1
    await RisingEdge(dut.clk)
    dut.res_ack.value = 0
    await RisingEdge(dut.clk)

    assert int(dut.state.value) == ALU_IDLE, "Should return to IDLE"


@cocotb.test()
async def div_multi_cycle_test(dut):
    """Verify DIV takes multiple cycles"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    dut.src1.value = 100
    dut.src2.value = 7
    dut.mdu_control.value = ALU_DIV
    dut.req_valid.value = 1

    await RisingEdge(dut.clk)
    dut.req_valid.value = 0

    # Should go to BUSY
    await RisingEdge(dut.clk)
    assert int(dut.state.value) == ALU_BUSY, "DIV should be in BUSY state"

    # Count cycles until DONE
    cycles = 1
    while int(dut.state.value) == ALU_BUSY:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 40:
            raise RuntimeError("DIV took too many cycles")

    assert int(dut.state.value) == ALU_DONE, "DIV should reach DONE"
    assert int(dut.res_valid.value) == 1, "res_valid should be high"
    assert int(dut.mdu_result.value) == 14, "100 / 7 = 14"

    dut._log.info(f"DIV completed in {cycles} cycles")

    # Acknowledge
    dut.res_ack.value = 1
    await RisingEdge(dut.clk)
    dut.res_ack.value = 0
    await RisingEdge(dut.clk)

    assert int(dut.state.value) == ALU_IDLE, "Should return to IDLE"


@cocotb.test()
async def div_by_zero_fast_test(dut):
    """Verify division by zero completes quickly (corner case optimization)"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    dut.src1.value = 12345
    dut.src2.value = 0
    dut.mdu_control.value = ALU_DIV
    dut.req_valid.value = 1

    await RisingEdge(dut.clk)
    dut.req_valid.value = 0

    # Count cycles until DONE
    cycles = 0
    while int(dut.state.value) != ALU_DONE:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 5:
            break

    dut._log.info(f"DIV by zero completed in {cycles} cycles")

    assert int(dut.res_valid.value) == 1, "res_valid should be high"
    assert int(dut.mdu_result.value) == 0xFFFFFFFF, "DIV by zero should return -1"

    # Acknowledge
    dut.res_ack.value = 1
    await RisingEdge(dut.clk)
    dut.res_ack.value = 0


@cocotb.test()
async def back_to_back_operations_test(dut):
    """Test multiple operations in sequence"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    operations = [
        (ALU_MUL, 5, 6, 30),
        (ALU_MULHU, 0x80000000, 2, 1),
        (ALU_DIVU, 100, 10, 10),
        (ALU_REMU, 17, 5, 2),
        (ALU_MUL, 0xFFFFFFFF, 0xFFFFFFFF, 1),
    ]

    for control, src1, src2, expected in operations:
        result = await mdu_operation(dut, src1, src2, control)
        assert result == expected, f"Op {control}: {src1}, {src2} -> expected {expected}, got {result}"


@cocotb.test()
async def no_req_no_change_test(dut):
    """Verify MDU stays idle when req_valid is not asserted"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    # Set operands but don't assert req_valid
    dut.src1.value = 100
    dut.src2.value = 50
    dut.mdu_control.value = ALU_MUL
    dut.req_valid.value = 0

    for _ in range(10):
        await RisingEdge(dut.clk)
        assert int(dut.state.value) == ALU_IDLE, "MDU should stay IDLE"
        assert int(dut.res_valid.value) == 0, "res_valid should stay low"


@cocotb.test()
async def result_held_until_ack_test(dut):
    """Verify result is held until acknowledged"""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    dut.src1.value = 7
    dut.src2.value = 8
    dut.mdu_control.value = ALU_MUL
    dut.req_valid.value = 1

    await RisingEdge(dut.clk)
    dut.req_valid.value = 0

    # Wait for result
    while int(dut.res_valid.value) == 0:
        await RisingEdge(dut.clk)

    # Don't acknowledge, verify result stays valid
    for _ in range(5):
        await RisingEdge(dut.clk)
        assert int(dut.state.value) == ALU_DONE, "Should stay in DONE"
        assert int(dut.res_valid.value) == 1, "res_valid should stay high"
        assert int(dut.mdu_result.value) == 56, "Result should be held"

    # Now acknowledge
    dut.res_ack.value = 1
    await RisingEdge(dut.clk)
    dut.res_ack.value = 0
    await RisingEdge(dut.clk)

    assert int(dut.state.value) == ALU_IDLE, "Should return to IDLE after ack"