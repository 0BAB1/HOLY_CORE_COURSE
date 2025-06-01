<!--
SOFTWARE EDITION TUTORIAL

AUTHOR :  BABIN-RIBY Hugo a.k.a. BRH

Plese refer to the LICENSE for legal details on this document

LAST EDIT : 05/25
-->

# SOFTAWRE EDITION

## The goal of the *SOFTWARE EDITION*

Now that we can use our core on a basic SoC, things start to get interesting. We can write stuff and read sensors using assembly and it works great.

But something feels off : Productivity.

Yes I know, we are not here to revolutionize anything, but if we want to use the core on a larger project, pure assembly is quickly going to be annoyingly slow.

The goal is simple here : **Make software developement easier**.

For this, it's simple: we'll need to compile from C. From there we'll be able to define handy libraries and use other people's library instread of spending 2 whole day reading datasheets to get pressure reading from a sensor using an assembly house of cards (speaking from experience, and yes this is the reason why I decided to start this edition).

> And even if bare metal librairies are not common for sensors (they all are made for arduino), we'll at least be able to adapt them, thus saving some time to implement sensor interactions.

Here's what we want to to do in this edition to make the dev's life easier :

- Use basic C librairies and compile programs for the core.
- Have a better boot loader to
  - Load programs from a live debugger
  - Or loads programs from an SD card on the SoC

As you can see there is a lot of works in all fields :

- Hardware
  - We need to better our testing solution to make sure our core is 100% compliant (at least for MCU applications).
- Software
  - We need to add a trap handler and basic bare metal utilities for ecalls (more on that later).
  - We need to develop bootloader solutions.
- SoC
  - We need to reorganize our SoC to be more versatile
  - Add an SD Card "data mover" and a way to communicate with a debugger

## 0: Ensuring compliance

Before writing **ANY PIECE OF SOFTWARE**, we need to make sur eveything we did until now is compliant with the RISC-V specs. This is because standard librairies we'll use down the road to lots of things and they don't care about our specific problems and hacks we made on the core's design back in the *previous editions*. We, as the designers, knew how to work around them when writing bare metal assembly. But standard pieces of code won't care.

So we'll use the [Riscof framework](https://riscof.readthedocs.io/en/latest/intro.html) to check our compliance.

To be honest, understading riscof is just so boring and such a pain as the docs are, like many low level projects docs, so weirdly put together. Like they always spend 10 lines explaining useles stuff and go over the core principles so fast. They always stay vague and use complicated words only to start digging in the details with a bad example.

> Yes I am fustrated and the are free and open source... But still ! It's always the same ! you spend 99% of the time yawning at their docs or trying ti unravel the meaning of what you're reading. It's crazy !

I'll let you go through the [quickstart guide to install everything you need](https://riscof.readthedocs.io/en/latest/installation.html).

Anyway, here is the big picture :

- Riscof is a set of assembly tests
- You use Riscof to run these tests on **2 targets:**
  - A sail golden reference (yet another language, meant to describe ISAs like RISC-V)
  - And of course... The *HOLY CORE* or whatever core you want to test.
- The goal : The results of the programs on the *HOLY CORE* have to be the same as the one from the **SAIL golen reference**.

> So Yeah, Riscof basically provides the assembly tests and then serves as a "comparing" tool.

Before diving into how Riscof works, let's prepare our HOLY CORE testbench for riscof. To do so, let's make a quick reminder on how cocotb works :

1. You call make on a makefile that sets up your sources for the tb (you HDL and testbench environement)
2. This makefile internally calls cocotb's makefile
3. Cocotb's makefile compile eveything using **Verilator** (or whatever simulator you chose)
4. Cocotb runs your compiled tb under the hood using High level and handy python assertions

> I love cocotb !

So quick reminder, again : Our *HOLY CORE* testbench includes the following :

- The holy core, wrapped in what I call `axi_translators` or `test_harness` which demuxes the AXI signals for cocotb to understand
- Some AXI LITE and AXI slave rams (to load program and simulate MMIO interaction)
- And that's it

At the beginning of the testbench, we load the `test_imemory.hex` program which contains our simple test program on which we run assertions to see if the core behaves correctly. It looks like this :

```c
// test_imemory.hex

000011B7  //DATA ADDR STORE     lui x3 0x1          | x3  <= 00001000
0081A903  //LW  TEST START :    lw x18 0x8(x3)      | x18 <= DEADBEEF
0121A623  //SW  TEST START :    sw x18 0xC(x3)      | 0xC <= DEADBEEF
0101A983  //ADD TEST START :    lw x19 0x10(x3)     | x19 <= 00000AAA
01390A33  //                    add x20 x18 x19     | x20 <= DEADC999
01497AB3  //AND TEST START :    and x21 x18 x20     | x21 <= DEAD8889
0141A283  //OR  TEST START :    lw x5 0x14(x3)      | x5  <= 125F552D
0181A303  //                    lw x6 0x18(x3)      | x6  <= 7F4FD46A
0062E3B3  //                    or x7 x5 x6         | x7  <= 7F5FD56F

// ...
// And all the rest...
// ...
```

So the goal is is for us to be able to **specify what program to load in memory**. With such a feature in place, Instead of loading our test program, we could load riscof's test program and then exctract memory content from the BRAM (called **signature** in riscof) and we'll let riscof compare it to the golden result.

To do so, we copy `<software_edition_root>/tb/holy_core/` as `<software_edition_root>/riscof/holy_core_tb/` and we'll modify both the `Makefile` and the `test_holy_core.py`.

> Note : wehen beginning this edition, `<software_edition_root>` is just the copy pasted **fpga_edition** where we left it. As always, we build on top of the last edition.

In the makefile, we'll write :

```bash
# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs
WAVES = 1

VERILOG_SOURCES += $(wildcard $(PWD)/../../src/*.sv)
EXTRA_ARGS += $(PWD)/../../packages/holy_core_pkg.sv
EXTRA_ARGS += $(PWD)/../../packages/axi_if.sv
EXTRA_ARGS += $(PWD)/../../packages/axi_lite_if.sv
EXTRA_ARGS += $(PWD)/holy_test_harness.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_test_harness

# MODULE is the basename of the Python test file
MODULE = test_holy_core

# HEX FILE ABSOLUTE PATH TO PROGRAM
IHEX_PATH ?= $(PWD)/test_imemory.hex # NEW !!!
export IHEX_PATH

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
```

What `IHEX_PATH ?= $(PWD)/test_imemory.hex` does is it check if we specified this env variable when executing `make`. If not, we set it to `test_imemory.hex` by default. This way, when we run our tb normally, the default test program (ours) gets executed, but is we run something like :

```bash
IHEX_PATH="/path/to/test/program.hex" make
```

Then it loads the specified programs in our fake tb's memory. To take this new path into account, we also modify our `test_holy_core.py` file :

```python
# test_holy_core.py

import os
# other imports ...

# ...

    program_hex = os.environ["IHEX_PATH"]
    await init_memory(axi_ram_slave, program_hex, 0x0000)
    await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)

# ...
```

> Note : `init_memory()` is an *in house* utility function

And boom ! Right now we load the program in a weird way where we link instruction (*.text*) and data (*.data*) manually and we "only" have 4kB of memory which is 1024 instructions MAX.

Riscof on the other hand, will gladly ignore that and each program will have its own linker file. To make sure this isn't a problem later, we'll check for the specified program. If it's our custom program, we load as we are doing now. If not, we only load the specified program and now our manual *.data* section.

We'll also set the program's base address to `0xC`. This way, we'll have room to squeeze two intrctions before each program :

```assembly
lui x7, 0xFFFFF
csrrw x0, 0x7C1, x0          # non cachable base
csrrw x0, 0x7C2, x7          # non cacheble limit
```

Why ? Well, if you recall correctly from the *FPGA EDITION*, we can use these custom CSRs to set what range will use AXI LITE to avoid being cache. We do this here to avoid caching effect where we won't be able to gather the information we need in RAM at the end of the testbench.

These 3 instructions effectively makes the whole memory non cachable from the data cache's perspective. We'll also add a dumb loop at the end to "let the tests pass".

```python
# test_holy_core.py

@cocotb.test()
async def cpu_insrt_test(dut):

    await inst_clocks(dut)

    SIZE = 2**14
    axi_ram_slave = AxiRam(AxiBus.from_prefix(dut, "m_axi"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    axi_lite_ram_slave = AxiLiteRam(AxiLiteBus.from_prefix(dut, "m_axi_lite"), dut.aclk, dut.aresetn, size=SIZE, reset_active_level=False)
    await cpu_reset(dut)

    program_hex = os.environ["IHEX_PATH"]
    axi_ram_slave.write(0x0, int("FFFFF3B7", 16).to_bytes(4,'little'))
    axi_ram_slave.write(0x4, int("7C101073", 16).to_bytes(4,'little'))
    axi_ram_slave.write(0x8, int("7C239073", 16).to_bytes(4,'little'))
    await init_memory(axi_ram_slave, program_hex, 0x000C)

    if "test_imemory.hex" in program_hex:
        # If we are loading custom program, also manually load custom init .data
        await init_memory(axi_ram_slave, "./test_dmemory.hex", 0x1000)

  
    ############################################
    # TEST BENCH
    ############################################

    while dut.core.stall.value == 1:
        await RisingEdge(dut.clk)

    # Verify that we execute our non-cachable setup
    assert dut.core.instruction.value == 0xFFFFF3B7
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C101073
    await RisingEdge(dut.clk)
    assert dut.core.instruction.value == 0x7C239073
    await RisingEdge(dut.clk)

    # actual test program execution
    for _ in range(10_000):
        await RisingEdge(dut.clk)
```

Okay, now we are kinda ready to start looking into riscof

- riscof setup --dutname=holy_core
  - change into dumb brick configs
  - based on riscv configs https://github.com/riscv-software-src/riscv-config/tree/dev/examples
- riscof --verbose info arch-tests --clone (get tests)
