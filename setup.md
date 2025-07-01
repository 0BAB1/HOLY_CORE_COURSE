# HOLY CORE : The setup

Welcome back ! Let's get you up to speed how how we'll setup our project to start working as soon as possible !

## Tools used for the project

### Prerequisites

I suggest you use **LINUX** (or MacOS) as the tech stack used is fully open source, meaning most of the support is towards linux. Windows might work, but I did not even try.

You also need to install the stack described below.

To start this course you also need to have these basics down :

- Python programming.
- RISC-V assembly.
- SystemVerilog / HDL and digital design knowledge.

### The HDL : SystemVerilog

SystemVerilog is used, you don't need to install anything to write in this language, only a text editor.

We'll also use plain verilog as well for wrapping the design in the later *fpga edition* section.

### Simulator :  Verilator

This course uses Verilator as a simulator. It is an opensource "*heavy-weight*" simulator but pretty performant once everything is compiled. You can also use icarus verilog for the first block (until the last *single cycle edition* chapter where we start using systemVerilog features non-supported by icarus, so I would not recommend).

To get your hands on Verilator, I suggest you use the [git install](https://verilator.org/guide/latest/install.html#git-quick-install) method as not all the ```apt``` repos are up-to-date.

### TestBenches : cocotb

Verilator has a learning curve. So does testbench design.

To make the testing phase as easy as possible for everyone, I chose to use **cocotb**.

Cocotb is a way to write testbenches in python and run it by specifying few options in a makefile and then run simulation in the backend **without having to touch verilator** (which is great).

To install, here are some directions to install it on your system :

[Cocotb website](https://www.cocotb.org/)

[Install docs](https://docs.cocotb.org/en/stable/install.html)

[My blog post on cocotb for tips](https://0bab1.github.io/BRH/posts/TIPS_FOR_COCOTB/)

Useful commands :

``sudo apt-get install make python3 python3-pip libpython3-dev``

``pip install cocotb``

## CODE BASE STRUCTURE and TESTS SETUP

### Choosing your edition

This course contains multiple "blocks" that aims at teaching different aspects of designing your own CPU.
Each of these block has its own subfolder (e.g. `single_cycle_edition` or `fpga_edition`).

### Cleaning a project

When doing tests, each simulation creates a bunch of log & build folders. You can get rid of them by running `make clean` @ the root of the edition you're working on (thus the `Makefile` at each edition's root).

### Course edition structure

An edition is structure like so :

```txt
example_edition/
- fpga/
- packages/
- src/
- tb/
```

- `src` contains all the base HDL source code that describe all of the core's logic at the RTL level.
- `tb` contains all the cocotb testbenches and related HDL wrappers when needed. More on that in the next subsection.
- `packages` is a folder that appears in the late *single_cycle_edition* that hosts config file to avoid hardcoding every value.
- `fpga` is a folder that appears in the late `fpga_edition` and contains files for the FPGA implementation of the core.

### Testing : using cocotb and tb folders structure

The tb folder is organised like so :

```txt
tb/
- module1/
- - Makefile
- - test_module1.py

- module2/
- - Makefile
- - test_module2.py
- - wrapper_if_needed.sv

- module3/
- - Makefile
- - test_module3.py
- - memory_init.hex

- ...
- Other_modules.../
- ...

- test_runner.py
```

Each module corresponds to a module present in the `src/` folder.

As you can see, depending on the Design Under Test (DUT) we can add verious files needed for simulation like an `hex` file or a *system verilog* wrapper. When such files are needed, the tutorial will notify it on the fly with guidance on how to do it.

There is also a **test runner** used to run all tests at once using `pytest`.

To learn more, I recommend reading this blog post I made : [cocotb blog post link](https://0bab1.github.io/BRH/posts/TIPS_FOR_COCOTB/)

#### Quick shortcut links for those who know how to use cocotb

- For the setting up your own "makefile" : [Cocotb makefile link](https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile)
- To setup you own runner : [Test runner setup link](https://docs.cocotb.org/en/latest/runner.html)

### Fpga edition : using cocotb axi extension

In FPGA edition, we'll design custom AXI interfaces. To make sure they are compliant, we'll not rely on faith and prayers but rather some prebuilt modules that we can use in simulation to make sure our DUT's AXI interface behaves correctly. More on that here : [cocotb blog post link](https://0bab1.github.io/BRH/posts/TIPS_FOR_COCOTB/)

## What now ?

If you understood how the project is set up, then you can now create a very basic project using the same structure as described earlier and start from there with the *single cycle edition* folder and check out the readme inside it.

Happy learning !
