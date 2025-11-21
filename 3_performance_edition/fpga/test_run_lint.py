# HOLY_CORE *Internal* SoC TESTBECH (FPGA + CHECKS)
#
# This test runs on the top module
# detnied to FPGA use. The goal is to LINT
# this code and check how the internal SoC
# bhaves and interacts with externals before
# throwing it in vivado. We also us this
# TB to freely run various SoC level tests 
# to check if the core reacts as expected
# in the internal SoC.
#
# Because the DUT is the atual FPGA top module,
# ROM will be at address 0. To modify said ROM,
# instructions are in this ./ROM/readme.md folder.
#
# Because this is a cocotb testbench for the
# internals of the SoC, there is no RAM and
# we use cocotb's simulated AXI RAM. It is initally
# loaded with the program in ./test_program.hex
# simply drop in any hex you want. Note that you
# can grab .hex dumps in the <root>/example program
# after compilation, allowing to simulate whatever
# you want External read/write, that would usually
# be destined for external controlers like UART or GPIO
# will be done on a blank RAM slave as well.
#
# BRH 11/25

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
CPU_PERIOD = 10
NUM_CYCLES = 10_000

@cocotb.coroutine
async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    dut.periph_rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    dut.periph_rst_n.value = 1
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

@cocotb.coroutine
async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())

@cocotb.coroutine
async def init_memory(axi_ram : AxiRam, hexfile, base_addr):
    addr_offset = 0
    with open(hexfile, "r") as file:
        for raw_instruction in file :
            addr = addr_offset + base_addr
            str_instruction = raw_instruction.split("/")[0].strip()
            instruction = int(str_instruction, 16).to_bytes(4,'little')
            axi_ram.write(addr, instruction)
            axi_ram.hexdump(addr,4)
            addr_offset += 4

@cocotb.test()
async def cpu_insrt_test(dut):
    await inst_clocks(dut)

    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=0x90000000, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=0x90000000, reset_active_level=False)

    await cpu_reset(dut)

    # Init the memories with the program data. Both are sceptible to be queried so we init both.
    # On a real SoC, a single memory will be able to answer bot axi and axi lite interfaces
    # hex_path = "./doom.hex"
    hex_path = "./hello_world.hex"
    await init_memory(axi_ram_slave, hex_path, 0x80000000)
    await init_memory(axi_lite_ram_slave, hex_path, 0x80000000)

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)

    num_cycles = 0
    num_instr = 0
    num_i_stall = 0
    num_d_stall = 0
    num_d_stall_on_real_data = 0
    num_branches = 0
    num_jumps = 0
    num_branches_taken = 0

    # DOOM profiling: we let the game run for basic performance metrics review.
    for _ in range(NUM_CYCLES):
        await RisingEdge(dut.clk)
        num_cycles += 1

        if dut.core.trap.value or dut.core.exception.value== 1:
            dut._log.critical("Unexpected exception !")
            for _2 in range(500):
                await RisingEdge(dut.clk)
            return 

        if num_cycles % 5000 == 0:
            print("===============")
            print("cycles : ", num_cycles)
            print("instr : ", num_instr)
            print("i stall : ", num_i_stall)
            print("d stall : ", num_d_stall)
            print("real d stall : ", num_d_stall_on_real_data)
            print("b : ", num_branches)
            print("taken b : ", num_branches_taken)
            print("j : ", num_jumps)

        # Stalls
        if dut.core.i_cache_stall.value == 1:
            num_i_stall += 1

        if dut.core.d_cache_stall.value == 1:
            num_d_stall += 1
            if int(dut.core.alu_result.value) > int(0x80000000):
                num_d_stall_on_real_data += 1

        # Get instruction bits
        instr = dut.core.instruction.value & 0xFFFFFFFF
        opcode = instr & 0x7F

        # Count BRANCH instructions (opcode = 1100011 = 0x63)
        if opcode == 0x63 and dut.core.stall.value != 1:
            num_branches += 1

        # Count JAL (0x6F)
        if opcode == 0x6F:
            num_jumps += 1   # treat as branch-type instr

        # Count JALR (0x67)
        if opcode == 0x67:
            num_jumps += 1   # treat as branch-type instr

        # Detect TAKEN (control-stage) branch/jump
        if dut.core.control_unit.assert_branch.value == 1:
            num_branches_taken += 1

        # Count executed instructions (only if not stalled)
        if dut.core.stall.value == 0:
            num_instr += 1

    dut._log.critical("=========================================")
    dut._log.critical("        HOLY-CORE RISC-V REPORT")
    dut._log.critical("=========================================")
    dut._log.critical(f"Cycles                        : {num_cycles}")
    dut._log.critical(f"Instructions executed         : {num_instr}")
    dut._log.critical(f"I-cache stalls                : {num_i_stall}")
    dut._log.critical(f"D-cache stalls (all)          : {num_d_stall}")
    dut._log.critical(f"D-cache stalls (real data)    : {num_d_stall_on_real_data}")
    dut._log.critical(f"Branch instructions           : {num_branches}")
    dut._log.critical(f"Jump instructions             : {num_jumps}")
    dut._log.critical(f"Branches/jumps actually taken : {num_branches_taken}")

    # Derived metrics
    if num_instr > 0:
        cpi = num_cycles / num_instr
        ipc = num_instr / num_cycles
        dut._log.critical(f"CPI                           : {cpi:.3f}")
        dut._log.critical(f"IPC                           : {ipc:.3f}")
    else:
        dut._log.critical("CPI / IPC                      : N/A (0 instructions)")

    # Optional percentages
    if num_cycles > 0:
        dut._log.critical(f"I-cache stall %                : {num_i_stall / num_cycles * 100:.2f}%")
        dut._log.critical(f"D-cache stall % (all)          : {num_d_stall / num_cycles * 100:.2f}%")
        dut._log.critical(f"D-cache stall % (real data)    : {num_d_stall_on_real_data / num_cycles * 100:.2f}%")

    dut._log.critical("=========================================")

        


    return