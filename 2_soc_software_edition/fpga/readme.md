<!-- BRH 11/2025 to help people figure out what's going on here-->
# FPGA FOLDER

Here you will find a top module : `holy_top.sv` which is the basic internal exmaple HOLY SoC.

It comes with:

- A **CLINT** (timer)
- A **PLIC** (interrupt controller)
- the actual **HOLY CORE**
- a static **ROM** (hardcoded)

To modify the `ROM/`, go in the ROM folder

## Simulation

You can simulate the internal SoC. PC starts at `0x00000000` value, which is where the ROM is located.

The goal of this specific testbench is not to assert any behavior to verify compliance, but rather serve
as a quick and easy way to LINT the system's code and test/debug some more advanced SoC behavior more freely.
than in the more rigid unit testbenches.

The cocotb tb will load the `./soc_test_program.hex` at `0x80000000`.

From there, you can simulate anything you want, except no real external UART, GPIO, etc.. exist.

> **More infos** in the header comments of `./test_run_lint.py`