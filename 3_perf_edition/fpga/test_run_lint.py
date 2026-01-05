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
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
from cocotb.handle import Force, Release

# WARNING : Passing test on async clocks does not mean CDC timing sync is met !
CPU_PERIOD = 10
NUM_CYCLES = 1_000_000

CSR_MAP = {
    0x300: "mstatus",
    0x301: "misa",
    0x304: "mie",
    0x344: "mip",
    0x305: "mtvec",
    0x341: "mepc",
    0x342: "mcause",
    0x343: "mtval",
    0x340: "mscratch",
    0x7C0: "flush_cache",
    0x7C1: "data_non_cachable_base",
    0x7C2: "data_non_cachable_limit",
    0x7C3: "instr_non_cachable_base",
    0x7C4: "instr_non_cachable_limit"
}

def format_gpr(idx):
    """Used for debug logs."""
    if idx < 10:
        return f"x{idx} "
    else:
        return f"x{idx}"

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
    hex_path = "./hello_world_screen.hex"
    await init_memory(axi_ram_slave, hex_path, 0x80000000)
    await init_memory(axi_lite_ram_slave, hex_path, 0x80000000)

    # actual test program execution
    STOP_PC = 0x8000010c
    THRESHOLD = 30_000_000
    i = 0

    while not dut.core.pc.value.integer == STOP_PC or i >= THRESHOLD:
        i+=1

        await Timer(1, units="ns") # let signals info propagate in sim
        if i%1000 == 0:
            print(f'PC : {hex(dut.core.pc.value.integer)} / CYCLE : {i}')

        # if we're about to execute the instruction, we can log.
        if dut.core.stall.value == 0:
            # --- Initialize logging strings
            str_ifu = ""
            str_gpr = ""
            str_lsu = ""
            str_csr = ""

            # --- GPR write-back logging ---
            write_back_val = int(dut.core.write_back_signal.value) # packed type
            wb_data = (write_back_val >> 1) & 0xFFFFFFFF  # bits [32:1]
            wb_valid = write_back_val & 0x1               # bit [0]

            if dut.core.reg_write.value and wb_valid:
                if dut.core.dest_reg.value.integer != 0:  # ignore x0
                    reg_id = dut.core.dest_reg.value.integer
                    reg_val = wb_data
                    str_gpr = f" {format_gpr(reg_id)} 0x{reg_val:08x}"
                else:
                    str_gpr = ""
            else:
                str_gpr = ""

            # --- CSR write-back logging ---
            if dut.core.csr_write_enable.value:
                # build the reg id str
                # format cXXX_NNNNN
                # with XXX the decimal address
                # and NNNNN the csr standard name
                csr_addr = int(dut.core.csr_address.value)
                csr_name = CSR_MAP[csr_addr]
                csr_wb_data = dut.core.csr_write_back_data.value.integer
                str_csr = f" c{str(csr_addr)}_{str(csr_name)} 0x{csr_wb_data:08x}"
            else:
                str_csr = ""

            # --- LSU memory logging ---
            if dut.core.mem_write_enable.value:  # memory store
                # address comes from alu_result directly in holy_core
                addr = dut.core.alu_result.value.integer
                data = dut.core.mem_write_data.value.integer
                str_lsu = f" mem 0x{addr:08x} 0x{data:08x}"
            elif dut.core.mem_read_enable.value:  # memory load
                addr = dut.core.alu_result.value.integer
                data = dut.core.mem_read.value.integer
                str_lsu = f" mem 0x{addr:08x}"

            # --- Instruction fetch logging ---
            pc = dut.core.pc.value.integer
            instr = dut.core.instruction.value.integer
            instr_size = 4  # instruction are always 4 bytes for now...

            if instr_size == 4:
                str_ifu = f" 0x{pc:08x} (0x{instr:08x})"
            else:
                # not used but its here, we nere know ;)
                str_ifu = f" 0x{pc:08x} (0x{instr & 0xFFFF:04x})"

            # --- Write final combined log line ---
            with open("dut.log", "a") as fd:
                fd.write(f"core   0: 3{str_ifu}{str_gpr}{str_lsu}{str_csr}\n")
            
        await RisingEdge(dut.clk)

    print("OVER!")
    await ClockCycles(dut.clk, 200)
