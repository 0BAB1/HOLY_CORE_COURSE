import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def basic_count(dut):
    #clk gen
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())

    #reset and hold for 2 clk posedge
    dut.rst.value = 1
    for _ in range (2):
        await RisingEdge(dut.clk)
    dut.rst.value = 0

    # run for 50ns, with assertion
    for cnt in range(1025):
        await RisingEdge(dut.clk)
        dut_cnt = int(dut.cnt.value)
        predicted = (cnt) % 256
        assert dut_cnt == predicted, \
            f"{dut_cnt} != predicted : {predicted}"