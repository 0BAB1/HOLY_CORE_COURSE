# HOLY CORE : The setup

Welcome back ! Maybe you did not read the readme first, so please read it here : [readme](./readme.md)

## The tutorials

Before diving into the tutorials, it is **mandatory** to setup your environement correctly first using the guidelines below.

If you already did that, know that the repo is organized in branches, one per block. The first block's tutorial (single cycle RV32I) is completely free in *MarkDown* format but you can buy the PDF edition to support me (it contains more details, my own notes and some personal easter eggs too ;p). Other blocks are paid but you can still access the source code if you want.

So, once the setup is done, open the PDF of the block you want to build or access the first tutorial for free [here](./tutorial.md).

## Tools stack used for the project

### Prerequestites

I suggest you use LINUX as the tech stack used is fully open source, meaning most of the support is towards linux.

(I managed to get it to *somewhat* work on windows, even though I still get errors, meaning it is far from a stable solution.)

You also need to install the stack described below.

To start this course you also need to have these basics down :

- Python programming.
- RISC-V assembly.
- SystemVerilog / HDL knowledge.

### The HDL

SystemVerilog is used, you don't need to install anything to write in this language if not a text editor.

### Simulator :  Verilator

This course uses Verilator as a simulator. It is an opensource heavy-weight simulator but pretty performant once everythong is compiled. You can also use icarus verilog for the first block (until the last chapter where we start using systemVerilog features non-supported by icarus).

I suggest you use the [git install](https://verilator.org/guide/latest/install.html#git-quick-install) method as not all the ```apt``` repos are up-to-date.

### TestBenches : cocotb

Verilator has a learning curve. So does testbench design.

To make the testing phase as easy as possible for everyone, I chose to use **cocotb**. cocotb is a way to write testbenches in python, specify some options in a makefile (like "use verilator") and then run simulation in the backend **without having to touch verilator** (which is simply great).

Here are some directions to install it on your system :

[WebSite](https://www.cocotb.org/)

[Install docs](https://docs.cocotb.org/en/stable/install.html)

Useful commands :

``sudo apt-get install make python3 python3-pip libpython3-dev``

``pip install cocotb``

## Seting up the tests

In this project, we'll setup the files as follows for the tests:

```txt
.
├── Makefile                      
├── setup.md
├── src                           // Contains the SystemVerilog HDL sources
│   ├── logic1.sv
│   └── logic2.sv
├── tb                            // Contains all the test benches
│   ├── test_logic1/
│   ├── test_logic2/
│   └── test_runner.py            // Run ALL the tb using "pytest" or "python test_runner.py" in this dir
├── todo.txt
└── tutorial.md                   // Main tutorial file
```

### Main Makefile

There is a main makefile at the root and it's only purpose is to clean the project once the simulations are done. run ```make clean``` to use it.

### tb folders

The testbenches are organised like so :

```
<!-- todo : work on the setup !! -->
```

For the "makefile" : [docs](https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile)
