# TESTRUNNER 
#
# BRH 10/24
#
# This file allows for a global deign test.
# It will run all test benches for each logic block.
# You can run tests indvidually (recommended for debugging)
# by going ito a design sub dir and simply running the "make" command
#
# https://docs.cocotb.org/en/latest/runner.html

import os
from pathlib import Path
from cocotbext.axi import AxiBus, AxiRam, AxiLiteBus, AxiLiteRam

from cocotb.runner import get_runner

def generic_tb_runner(design_name, specific_top_level=None, additional_sources=[], initial_sources=[], includes=[]):
    """
        initial sources : packages and "early" source files needed to build most modules
        additional sources : main source, Note: add top module last in these sources
        includes : self explainatory
    """
    print(initial_sources, additional_sources)
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__name__).resolve().parent.parent
    sources = list(proj_path.glob("src/*.sv"))
    runner = get_runner(sim)
    toplevel = specific_top_level if specific_top_level else design_name
    runner.build(
        sources=initial_sources+sources+additional_sources,
        hdl_toplevel=f"{toplevel}",
        build_dir=f"./{design_name}/sim_build",
        build_args=(
            ["-sv", "-Wall", "-Wno-fatal", "--trace", "--trace-structs"]
            + includes
            + [
                f"{proj_path}/packages/holy_core_pkg.sv",
                f"{proj_path}/packages/axi_if.sv",
                f"{proj_path}/packages/axi_lite_if.sv"
            ]
        )
    )
    runner.test(hdl_toplevel=f"{toplevel}", test_module=f"test_{design_name}", test_dir=f"./{design_name}")

def test_alu():
    generic_tb_runner("alu")

def test_control():
    generic_tb_runner("control")

def test_holy_core():
    proj_path = Path(__name__).resolve().parent.parent

    # this is kinda sloppy tbh, TODO: shoulf use .f files
    generic_tb_runner(
        "holy_core",
        specific_top_level="holy_test_harness",
        initial_sources=[
            # Verilog sources (packages)
            # f"{proj_path}/packages/holy_core_pkg.sv",
            f"{proj_path}/vendor/prim_util_pkg.sv",
            f"{proj_path}/vendor/axi_pkg.sv",
            f"{proj_path}/vendor/cf_math_pkg.sv",
            f"{proj_path}/vendor/axi_intf.sv",
            f"{proj_path}/vendor/rand_id_queue.sv",
            f"{proj_path}/tb/holy_core/axi_if_convert.sv",

            # external sources (mainly customized pulp platform files)
            f"{proj_path}/vendor/delta_counter.sv",
            f"{proj_path}/vendor/counter.sv",
            f"{proj_path}/vendor/fifo_v3.sv",
            f"{proj_path}/vendor/spill_register_flushable.sv",
            f"{proj_path}/vendor/spill_register.sv",
            f"{proj_path}/vendor/axi_lite_xbar.sv",
            f"{proj_path}/vendor/addr_decode_dync.sv",
            f"{proj_path}/vendor/addr_decode.sv",
            f"{proj_path}/vendor/axi_lite_demux.sv",
            f"{proj_path}/vendor/axi_lite_mux.sv",
            f"{proj_path}/vendor/axi_lite_to_axi.sv",
            f"{proj_path}/vendor/axi_err_slv.sv",
            f"{proj_path}/vendor/prim_clock_inv.sv",
            f"{proj_path}/vendor/prim_flop_2sync.sv",
            f"{proj_path}/vendor/prim_clock_mux2.sv",
            f"{proj_path}/vendor/prim_fifo_async_simple.sv",
            f"{proj_path}/vendor/prim_fifo_sync.sv",
            f"{proj_path}/vendor/prim_sync_reqack.sv",
            f"{proj_path}/vendor/prim_generic_clock_mux2.sv",
            f"{proj_path}/vendor/prim_flop.sv",
            f"{proj_path}/vendor/prim_fifo_sync_cnt.sv",
            f"{proj_path}/vendor/prim_generic_flop.sv"
        ],
        additional_sources= (
            list(proj_path.glob("src/holy_plic/*.sv"))
            + list(proj_path.glob("src/holy_clint/*.sv"))
            + [
                f"{proj_path}/tb/holy_core/holy_test_harness.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_csrs.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_mem.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_obi_top.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_pkg.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_sba.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dm_top.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dmi_cdc.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dmi_intf.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dmi_jtag_tap.sv",
                f"{proj_path}/vendor/pulp-riscv-dbg/src/dmi_jtag.sv"
            ]

            + list(proj_path.glob("vendor/pulp-riscv-dbg/debug_rom/*.sv"))
        ),
        includes=[
            f"-I{proj_path}/vendor/include",
            f"-I{proj_path}/vendor/include/common_cells",
            f"-I{proj_path}/vendor/include/axi"
        ]
    )

"""def test_memory():
    generic_tb_runner("memory")"""

def test_regfile():
    generic_tb_runner("regfile")

def test_signext():
    generic_tb_runner("signext")

def test_load_store_decoder():
    generic_tb_runner("load_store_decoder")

def test_reader():
    generic_tb_runner("reader")

def test_holy_instr_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_instr_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_instr_cache/axi_translator.sv"])

def test_holy_data_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_data_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_data_cache/axi_translator.sv"])

def test_holy_no_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_no_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_no_cache/axi_translator.sv"])

def test_external_req_arbitrer():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("external_req_arbitrer", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/external_req_arbitrer/axi_translator.sv"])

def test_csr_file():
    generic_tb_runner("csr_file")