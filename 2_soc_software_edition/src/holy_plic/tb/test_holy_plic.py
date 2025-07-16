# PLIC TESTBECH
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

NUM_IRQS = 5 # to adapt manually

def get_highest_priority_index(ref : list[int]):
    """
        This helper function returns the highest
        id given in the ref. 
    """
    max_index = 0
    for id,intr in enumerate(ref):
        if intr:
            max_index = id

    return max_index 

@cocotb.test()
async def main_test(dut):
    """
        In this test, we'll check *basic* compliance on the
        Privile
        ged specs for a PLIC. By "basic" is implied that
        some basic functionalities may not be supported yet.
        Don't hate though, it's just to make it literally as
        simple as possible.
    """

    # ==================================
    # CLOCKS & RAM DECLARATION
    # ==================================

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.clk, dut.rst_n, reset_active_level=False)
    dut.rst_n.value = 0b1

    await Timer(1, units="ns")

    # enable ALL interrupts
    signal_completion = await axil_master.write(0x0,int.to_bytes(0xFFFFFFFF,4,byteorder="little"))
    
    # ==================================
    # BASIC INIT TESTS
    # ==================================

    # The baseline should be NO REQUEST to target
    # if target try to do a poll claim, result is 0
    assert dut.ext_irq_o.value == 0b0
    claim_result = await axil_master.read(0x4,4)
    assert (
        int.from_bytes(claim_result.data, byteorder="little")
        == 0
    )

    # ==================================
    # BASIC RANDOM INTERRUPT TEST
    # ==================================

    # random tests, simply test a randomly asserted
    # interrupt, waits for the target notification.
    # claims it, clears it, signals completion.
    # the interrupt notification should then be 0 and
    # we move on to simulate antother random intr.
    for _ in range(100):
        random_id = random.randint(0,4)

        dut.irq_in[random_id].value = 0b1

        # wait for the gateways to synchronise
        while not dut.ext_irq_o.value:
            await RisingEdge(dut.clk)
        assert dut.ext_irq_o.value == 0b1
        
        # Then the target claims the interrupt
        # result of the read should be the id of the
        # interrupt.
        claim_result = await axil_master.read(0x4,4)
        assert (
            int.from_bytes(claim_result.data, byteorder="little")
            == random_id + 1
        )
        await RisingEdge(dut.clk)

        # external request should go low
        assert dut.ext_irq_o.value == 0b0

        # check internal in service signal
        assert dut.u_holy_plic.in_service.value == 1

        # simulate an handler running
        for _2 in range(10):
            await RisingEdge(dut.clk)
        
        # ext irq request is cleared by the target's actions
        dut.irq_in[random_id].value = 0b0

        # simulate an handler running
        for _2 in range(10):
            await RisingEdge(dut.clk)
        
        # signal completion
        signal_completion = await axil_master.write(0x4,claim_result.data)
        await RisingEdge(dut.clk)
        
        # check internal in service signal
        assert dut.u_holy_plic.in_service.value == 0

        # no more external interrupt at this point
        assert dut.ext_irq_o.value == 0b0

    # ==================================
    # CONCURENT INTERRUPTS TEST
    # ==================================

    # Testing for concurrent interrupts bahavior
    # PLIC.

    for _ in range(100):
        # init interrupts randomly.
        # Chances are multiple of them will
        # be set at once !
        irqs_ref = [0 for _2 in range(NUM_IRQS)]

        for i in range(NUM_IRQS):
            irqs_ref[i] = random.randint(0,1)
            dut.irq_in[i].value = irqs_ref[i]

        #wait a couple of cycles for gateways to sync
        for _3 in range(5):
            await RisingEdge(dut.clk)

        # Until every interrupt is cleared, we loop
        while not irqs_ref == [0 for _2 in range(NUM_IRQS)]:
            # determine highest priority on ref
            # then claim it and compare.
            expected_max_id = get_highest_priority_index(irqs_ref)
            # clear in the ref for next loop
            irqs_ref[expected_max_id] = 0

            claim_result = await axil_master.read(0x4,4)
            assert (
                int.from_bytes(claim_result.data, byteorder="little")
                == expected_max_id + 1
            )

            # simulate an handler running
            for _4 in range(10):
                await RisingEdge(dut.clk)
            
            # ext irq request is cleared by the target's actions
            dut.irq_in[expected_max_id].value = 0b0

            # simulate an handler running
            for _4 in range(10):
                await RisingEdge(dut.clk)

            # signal completion
            await axil_master.write(0x4,claim_result.data)
            await RisingEdge(dut.clk)