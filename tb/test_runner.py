# This file allows for a global deign test.
# It will run all test benches for each logic block.

# You can run tests indvidually (recommended for debugging)
# by going ito a design sub dir and simply running the "make" command

import os
from pathlib import Path

from cocotb.runner import get_runner

def generic_tb_runner(design_name):
    sim = os.getenv("SIM", "verilator")
    proj_path = Path(__name__).resolve().parent.parent
    sources = list(proj_path.glob("src/*.sv"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=f"{design_name}",
        build_dir=f"./{design_name}/sim_build"
    )
    runner.test(hdl_toplevel=f"{design_name}", test_module=f"test_{design_name}", test_dir=f"./{design_name}")


def test_alu():
    generic_tb_runner("alu")

def test_control():
    generic_tb_runner("control")

def test_cpu():
    generic_tb_runner("cpu")

def test_memory():
    generic_tb_runner("memory")

def test_regfile():
    generic_tb_runner("regfile")

def test_signext():
    generic_tb_runner("signext")

def test_load_store_decoder():
    generic_tb_runner("load_store_decoder")

def test_reader():
    generic_tb_runner("reader")

if __name__ == "__main__":
    test_alu()
    test_control()
    test_cpu()
    test_memory()
    test_regfile()
    test_signext()
    test_load_store_decoder()
    test_reader()