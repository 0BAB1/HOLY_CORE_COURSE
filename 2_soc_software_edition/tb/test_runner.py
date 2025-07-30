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
        additional sources : complementary "final" sources unused from outside the src/ folder
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

    generic_tb_runner(
        "holy_core",
        specific_top_level="holy_test_harness",
        initial_sources=[
            # Pulp AXI CROSSBAR sources for testbench
            f"{proj_path}/vendor/axi/src/axi_pkg.sv",
            f"{proj_path}/vendor/common_cells/src/cf_math_pkg.sv",
            f"{proj_path}/vendor/axi/src/axi_intf.sv",
            f"{proj_path}/vendor/common_verification/src/rand_id_queue.sv",
            f"{proj_path}/packages/axi_if.sv",
            f"{proj_path}/packages/axi_lite_if.sv",
            f"{proj_path}/tb/holy_core/axi_if_convert.sv",
        ]
        + [f for f in (proj_path / "vendor/axi/src").glob("*.sv") if f.name not in {"axi_pkg.sv", "axi_test.sv", "axi_intf.sv"}],
        additional_sources= (
            list(proj_path.glob("src/holy_plic/*.sv"))
            + list(proj_path.glob("src/holy_clint/*.sv"))
            + [
                f"{proj_path}/tb/holy_core/holy_test_harness.sv"
            ]
        ),
        includes=[
            f"-I{proj_path}/vendor/axi/include",
            f"-I{proj_path}/vendor/common_cells/include",
            f"-I{proj_path}/vendor/common_cells/src",
            f"-I{proj_path}/vendor/axi/src"
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

def test_holy_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_cache/axi_translator.sv"])

def test_holy_data_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_data_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_data_cache/axi_translator.sv"])

def test_holy_data_no_cache():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("holy_data_no_cache", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/holy_data_no_cache/axi_translator.sv"])


def test_external_req_arbitrer():
    proj_path = Path(__name__).resolve().parent.parent
    generic_tb_runner("external_req_arbitrer", specific_top_level="axi_translator", additional_sources=[f"{proj_path}/tb/external_req_arbitrer/axi_translator.sv"])

if __name__ == "__main__":
    test_alu()
    test_control()
    test_holy_core()
    """test_memory()"""
    test_regfile()
    test_signext()
    test_load_store_decoder()
    test_reader()
    test_holy_cache()
    test_holy_data_cache()
    test_holy_data_no_cache()
    test_external_req_arbitrer()