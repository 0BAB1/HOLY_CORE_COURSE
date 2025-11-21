# CLINT TESTBECH
#
# BRH 7/25

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

# AXI LITE SLAVE STATES
SLAVE_IDLE                  = 0b00
LITE_RECEIVING_WRITE_DATA   = 0b01
LITE_SENDING_WRITE_RES      = 0b10
LITE_SENDING_READ_DATA      = 0b11

@cocotb.test()
async def main_test(dut):
    """
        In this test, we'll check *basic* features of the CLINT.
        And verify in a simplt manner than interrupts are
        generated and cleared in an expected way.
    """

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.rst_n, reset_active_level=False)
    
    await Timer(100, units="ns")

    dut.rst_n.value = 0b1

    # ======================================
    # TIMER TEST INTR +  CLEAR, RANDOMIZED
    # ======================================

    for _ in range(100):
        ref = int(dut.u_holy_clint.timer.value)
        delta = random.randint(50, 500)

        await axil_master.write(0x4000, int.to_bytes(ref+delta,4,byteorder="little"))
        await axil_master.write(0x4004, int.to_bytes(000,4,byteorder="little"))

        i = 0
        init_timer = int(dut.u_holy_clint.timer.value)

        while not dut.timer_irq_o.value == 1:
            await RisingEdge(dut.clk)
            i += 1
            print(i)

        # i should be ref + delta - init tiamer (time it took to write mtimecmp)
        assert i == ref + delta - init_timer

    # ======================================
    # SIMPLE SOFT INTR TEST
    # ======================================

    await Timer(100, units="ns")
    assert dut.soft_irq_o.value == 0
    
    await axil_master.write(0, int.to_bytes(0x1,4,byteorder="little"))

    assert dut.soft_irq_o.value == 1
    await Timer(100, units="ns")
    assert dut.soft_irq_o.value == 1

    await axil_master.write(0, int.to_bytes(0x0,4,byteorder="little"))

    assert dut.soft_irq_o.value == 0
