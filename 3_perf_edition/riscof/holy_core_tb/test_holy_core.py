# HOLY_CORE TESTBECH
#
# Uses a pre-made hardcoded HEX program.
# WARNING : depending on cache state, the memory dumping has to be manually
# adapted ! see you at the end of the file. (todo: make this better)
#
# BRH 10/24

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam
import os

# WARNING : Passing test on async cloks does not mean CDC timing sync is met !
AXI_PERIOD = 10
CPU_PERIOD = 10

# increased threshold as high branching frequency
# makes cache tests go ever that limit
THRESHOLD = 200_000

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

def binary_to_hex(bin_str):
    # Convert binary string to hexadecimal
    hex_str = hex(int(str(bin_str), 2))[2:]
    hex_str = hex_str.zfill(8)
    return hex_str.upper()

def hex_to_bin(hex_str):
    # Convert hex str to bin
    bin_str = bin(int(str(hex_str), 16))[2:]
    bin_str = bin_str.zfill(32)
    return bin_str.upper()

def read_cache(cache_data, line) :
    """To read cache_data, because the packed array makes it an array of bits..."""
    l = 127 - line
    return (int(str(cache_data.value[32*l:(32*l)+31]),2))

def format_gpr(idx):
    """Used for debug logs."""
    if idx < 10:
        return f"x{idx} "
    else:
        return f"x{idx}"

async def cpu_reset(dut):
    # Init and reset
    dut.rst_n.value = 0
    await Timer(1, units="ns")
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

async def inst_clocks(dut):
    """this instantiates the axi environement & clocks"""
    cocotb.start_soon(Clock(dut.clk, CPU_PERIOD, units="ns").start())

async def init_memory(axi_ram : AxiRam, hexfile, base_addr):
    addr_offset = 0
    with open(hexfile, "r") as file:
        for raw_instruction in file :
            addr = addr_offset + base_addr
            str_instruction = raw_instruction.split("/")[0].strip()
            instruction = int(str_instruction, 16).to_bytes(4,'little')
            axi_ram.write(addr, instruction)
            print(f'RUNNING INIT @{hex(addr)} => {instruction}')
            axi_ram.hexdump(addr,4)
            addr_offset += 4

@cocotb.test()
async def cpu_insrt_test(dut):

    ############################################
    # TEST SYMBOLS GETTER
    ############################################

    # GET SIGNATURES SYMBOLS ADDRS FOR ENV PASSED VARS
    # passed sybols from plugin :
    # symbols_list = ['begin_signature', 'end_signature', 'tohost', 'fromhost']

    try :
        begin_signature = int(os.environ["begin_signature"],16)
        end_signature = int(os.environ["end_signature"],16)
        write_tohost = int(os.environ["write_tohost"],16)
    except ValueError:
        print("NO SYMBOLS PASSED, SKIPPING SIGNATURE WRITE, errors may occur")
    
    # Clear the log file before simulation starts
    with open("dut.log", "w"):
        pass  # Just open in write mode to truncate

    await inst_clocks(dut)

    SIZE = 2**32
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.clk, dut.rst_n, size=SIZE, reset_active_level=False)
    await cpu_reset(dut)

    startup_hex = "./test_startup.hex"
    program_hex = os.environ["IHEX_PATH"]    
    # add custom startup code (SHOULD CNTAIN A JUMP TO 0x80000000)
    await init_memory(axi_ram_slave, startup_hex, 0x0)
    await init_memory(axi_lite_ram_slave, startup_hex, 0x0)
    # add test code
    await init_memory(axi_ram_slave, program_hex, 0x80000000)
    await init_memory(axi_lite_ram_slave, program_hex, 0x80000000)

    print(f"begin_signature = {hex(begin_signature)}")
    print(f"end_signature = {hex(end_signature)}")
    print(f"write_tohost = {hex(write_tohost)}")
  
    ############################################
    # TEST BENCH
    ############################################

    # wait until we are about to jump to 0x8000_0000
    # to start counting...
    while not dut.core.pc_next.value == 0x8000_0000:
        await Timer(1,"ns")

    # we are about to jump to 0x8000_0000, we save pc to jump back
    # to _test_end (from test_startup.S) once the test is over to
    # execute final code
    _test_end_pc = dut.core.pc.value  + 4

    i = 0

    # actual test program execution
    while not dut.core.pc.value.integer >= write_tohost and i < THRESHOLD:
        i+=1

        await Timer(1, units="ns") # let signals info propagate in sim
        print(f'PC : {hex(dut.core.pc.value.integer)} <= {hex(write_tohost)}')

        ##########################################################
        # SPIKE LIKE LOGS (inspired by jeras' work, link below)
        # https://github.com/jeras/rp32/blob/master/hdl/tbn/riscof/r5p_degu_trace_logger.sv
        ##########################################################

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

    ############################################
    # FORCE JUMP TO _test_end_pc
    ############################################
    dut._log.info(f"Forcing PC directly to 0x{_test_end_pc:08X}")

    dut.core.pc.value = _test_end_pc
    for _ in range(1000):
        await RisingEdge(dut.clk)
    
    ############################################
    # SIGNATURE DUMP
    ############################################

    dump_dir = os.path.dirname(program_hex)
    dump_path = os.path.join(dump_dir, "DUT-holy_core.signature")

    with open(dump_path, 'w') as sig_file:
        collected_lines = []

        for addr in range(begin_signature, end_signature, 4):
            print(f'dumping addr {hex(addr)} in sig file')
            # WARNING : THINK ABOUT CHANGING THIS
            # DEPENDING ON THE CACHE SETUP !

            #word_bytes = axi_lite_ram_slave.read(addr, 4)
            word_bytes = axi_ram_slave.read(addr, 4)

            word = int.from_bytes(word_bytes, byteorder='little')
            hex_str = "{:08x}".format(word)  # always lowercase
            
            collected_lines.append(hex_str)

        # Write the actual signature
        for line in collected_lines:
            sig_file.write(line + "\n")