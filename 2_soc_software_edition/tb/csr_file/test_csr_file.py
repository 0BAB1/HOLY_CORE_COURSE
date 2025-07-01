# REGFILE TESTBECH
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import numpy as np
from copy import deepcopy

# For basic R/W randomized testing
RW_REGS = [0x7C0, 0x7C1, 0x7C2, 0x300, 0x304, 0x305, 0x341]

@cocotb.test()
async def test_csr_file(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # map each address to a register
    def get_csr_value(addr):
        if addr == 0x7C0:
            return dut.flush_cache.value
        elif addr == 0x7C1:
            return dut.non_cachable_base.value
        elif addr == 0x7C2:
            return dut.non_cachable_limit.value
        elif addr == 0x300:
            return dut.mstatus.value
        elif addr == 0x304:
            return dut.mie.value
        elif addr == 0x344:
            return dut.mip.value
        elif addr == 0x305:
            return dut.mtvec.value
        elif addr == 0x341:
            return dut.mepc.value
        elif addr == 0x342:
            return dut.mcause.value
        else:
            return 0

    for addr in RW_REGS:
        # ==================
        # BASIC R/W TESTS
        # ==================

        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # ----------------------------------
        # flush cache is 0 on start
        assert get_csr_value(addr) == 0x00000000

        # ----------------------------------
        # test simple write
        dut.write_enable.value = 1
        dut.write_data.value = 0xDEADBEEF
        dut.address.value = addr
        dut.f3.value = 0b001
        await RisingEdge(dut.clk)
        await Timer(2, units="ns")
        assert get_csr_value(addr) == 0xDEADBEEF
        assert dut.read_data.value == 0xDEADBEEF

        # ----------------------------------
        # nothing gets written if we flag is low
        dut.write_enable.value = 0b0
        dut.write_data.value = 0x12345678
        await RisingEdge(dut.clk)
        assert get_csr_value(addr) == 0xDEADBEEF

        # ----------------------------------
        # randomized test
        dut.write_enable.value = 0b1
        for _ in range(1000):
            await RisingEdge(dut.clk) #await antoher cycle to let flush cache reset if high
            await Timer(1, units="ns")

            init_csr_value = deepcopy(get_csr_value(addr))
            wd = random.randint(0, 0xFFFFFFFF)
            f3 = random.randint(0b000, 0b111)
            dut.write_data.value = wd
            dut.f3.value = f3

            await RisingEdge(dut.clk)
            await Timer(2, units="ns")
            if f3 == 0b000 or f3 == 0b100:
                assert dut.read_data == 0
            elif f3 == 0b001 or f3 == 0b101:
                assert (
                    dut.read_data.value
                    == wd
                )
            elif f3 == 0b010 or f3 == 0b110:
                assert (
                    dut.read_data.value
                    == (init_csr_value | wd)
                )
            elif f3 == 0b011 or f3 == 0b111:
                assert (
                    dut.read_data.value
                    == (init_csr_value & (~wd & 0xFFFFFFFF)) #we mask wd to 32 bits
                )
        
        # ----------------------------------
        # test reset, first write sample data
        dut.write_enable.value = 1
        dut.write_data.value = 0xDEADBEEF
        dut.address.value = addr
        dut.f3.value = 0b001
        await RisingEdge(dut.clk)

        # then we release reset and check for 0
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        assert get_csr_value(addr) == 0x00000000
        dut.rst_n.value = 1

        dut.write_enable.value = 0
        await Timer(1, units="ns")

    # ======================================
    # Traps CSRs behavior
    # ======================================

    # --------------------------------------
    # SIMPLE INTERUPTS TEST
    # --------------------------------------

    # No interrupt in sight => no trap
    await RisingEdge(dut.clk)
    assert dut.trap.value == 0
    await RisingEdge(dut.clk)

    # We set an interrupt
    dut.timer_itr.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    # All should be 0 because interrupts are not enabled
    assert dut.trap.value == 0
    assert dut.mcause.value == 0
    assert dut.mip.value == 1 << 7
    await RisingEdge(dut.clk)

    # we then enable interrupts
    dut.mstatus.value = dut.mstatus.value | 1 << 3
    dut.mie.value = 1 << 3 | 1 << 7 | 1 << 11
    # we also set test PCs for later assertion
    dut.current_core_pc.value = 0x8000
    dut.mtvec.value = 0x4000
    await RisingEdge(dut.clk)

    # should tigger the trapping flag
    assert dut.trap.value == 1
    await RisingEdge(dut.clk)

    # one the clock cycle after that, trap is taken
    # and new context is in !
    # mepc = old pc
    assert dut.mcause.value == 1 << 31 | 7
    assert dut.mtvec.value == 0x4000
    assert dut.mepc.value == 0x8000
    # MIE = 0, only MPIE = 1
    assert dut.mstatus.value == 1 << 7

    # we wait an arbitrary 50 clock cycles
    # Druing which the handler executes and clears the itr
    # and then another 50 cycles
    for _ in range(50):
        await RisingEdge(dut.clk)

    dut.timer_itr.value = 0

    for _ in range(50):
        await RisingEdge(dut.clk)

    # We get return order
    dut.m_ret.value = 1
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    dut.m_ret.value = 0
    await Timer(2, units="ns")

    # MIE should be back to normal
    # MIE = 1, only MPIE = X (1 in our scenario)
    assert dut.mstatus.value == 1 << 7 | 1 << 3

    # --------------------------------------
    # SIMPLE EXCEPTION TEST
    # --------------------------------------

    # No interrupt in sight => no trap
    await RisingEdge(dut.clk)
    assert dut.trap.value == 0
    await RisingEdge(dut.clk)

    # Control fetches an ecall and signals some exception
    dut.exception_cause.value = 11 # ecall
    dut.exception.value = 0b1
    await Timer(1, units="ns")

    assert dut.trap.value == 0b1
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")

    # Check how the CSRS react
    assert dut.mcause.value == 11
    assert dut.mepc.value == 0x8000
    # MIE = 0, only MPIE = 1
    assert dut.mstatus.value == 1 << 7

    # By the way, the CPU does not fetch ecall anymore !
    dut.exception.value = 0b0

    # we wait an arbitrary 50 clock cycles to emulate an handler
    for _ in range(50):
        await RisingEdge(dut.clk)

    # control signals mret is fetched
    dut.m_ret.value = 1
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    dut.m_ret.value = 0
    await Timer(2, units="ns")

    # MIE should be back to normal
    # MIE = 1, only MPIE = X (1 in our scenario)
    assert dut.mstatus.value == 1 << 7 | 1 << 3

    # ======================================
    # Custom CSRs behavior
    # ======================================

    # ----------------------------------
    # FLUSH CACHE CSR BEHAVIOR :
    # If this CSR's LSB is asserted, the module ouputs 1 on "flush"
    # order output for 1 cycle. This is automatically deasserted after a clock cycle

    # flush_cache_flag should be 0
    assert dut.flush_cache_flag.value == 0b0

    # Then we set all bits to 1 excpt LSB, should still be 0
    dut.write_enable.value = 1
    dut.write_data.value = 0xFFFFFFFE
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    assert dut.flush_cache.value == 0xFFFFFFFE
    assert dut.flush_cache_flag.value == 0b0

    # Then we write 1, should output 1
    dut.write_enable.value = 1
    dut.write_data.value = 0x00000001
    dut.address.value = 0x7C0
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    assert dut.flush_cache_flag.value == 0b1
    assert dut.flush_cache.value == 0x00000001

    # should go back to 0 after a single cycle
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    assert dut.flush_cache_flag.value == 0b0
    assert dut.flush_cache.value == 0x00000000
    dut.write_enable.value = 0

    # ----------------------------------
    # NON CACHABLE RANGE CSRS BEHAVIOR :
    # The are simple CSR with simple R/W logic and are never chnged by the system itself.
    # However, they do output their content in the non_cachable_base_addr and non_cachable_limit_addr (its the only thing we test for here)
    # There is no check for values, they can be anything, it's up to the user to set thme correctly, so not test for value

    # ------------------------------
    # CACHE BASE

    await RisingEdge(dut.clk)
    # write stuff to the cache base
    dut.write_enable.value = 1
    dut.address.value = 0x7C1
    dut.write_data.value = 0xAEAEAEAE
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    # check the output towards cache indicates good value
    assert dut.non_cachable_base_addr.value == 0xAEAEAEAE

    # ------------------------------
    # CACHE LIMIT

    await RisingEdge(dut.clk)
    # write stuff to the cache base
    dut.write_enable.value = 1
    dut.address.value = 0x7C2
    dut.write_data.value = 0xAEAEAEAE
    dut.f3.value = 0b001
    await RisingEdge(dut.clk)
    await Timer(2, units="ns")
    # check the output towards cache indicates good value
    assert dut.non_cachable_limit_addr.value == 0xAEAEAEAE