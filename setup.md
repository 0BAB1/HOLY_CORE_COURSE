# Single Cycle 32bits RISC-V CPU Tutorial

Let's make a CPU core using RISC-V !

For starters, we will start with a very simple simple cycle cpu, as it is the best begginer-friendly project to get started !

## The tutorial

VIDEO STILL IN DEV PHASE. Planned for end of november.

You can find the COMPLETE tutorial, from 0 to a fully working core [here](./tutorial.md).

## Tools stack used for the project

### Prerequestites

I suggest you use LINUX as the tech stack used is fully open source, meaning most of the support is towrds linux.

I managed to get it to somewhat work on windows, even though I dtill get errors, meaning it is not a viable solution.

You also need to install the stack described below.

### The HDL

SystemVerilog

### Simulator :  Verilator

### TestBenches : cocotb

[WebSite](https://www.cocotb.org/)

[docs](https://docs.cocotb.org/en/stable/install.html)

``sudo apt-get install make python3 python3-pip libpython3-dev``

``pip install cocotb``

for the "makefile" : [docs](https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile)

## Repo description

```txt
.
├── Makefile                      // run "make clean" to clean builds
├── setup.md
├── src                           // Contains the SystemVerilo HDL sources
│   ├── alu.sv
│   ├── control.sv
│   ├── cpu.sv
│   ├── memory.sv
│   ├── regfile.sv
│   └── signext.sv
├── tb                            // Contains all the test benches
│   ├── alu
│   ├── control
│   ├── cpu
│   ├── memory
│   ├── regfile
│   ├── signext
│   └── test_runner.py            // Run ALL the tb using "pytest" or "python test_runner.py" in this dir
├── todo.txt
└── tutorial.md                   // Main tutorial file
```

- **src**
  - Contains the sv source code for all of the modules
- **tb**
  - Contains the testbenches, each tesbench is a subdir. ```cd``` into it and run ```make``` to run an individual testbench
