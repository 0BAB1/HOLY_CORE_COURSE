# Holy Core - Dev Docs

Spoiler : Not much to see here as the whole dev process is already deocumented through the courses.

However, you'll find here some guidelines and simulation tips, as well as some notes for myself.

## RTL Contributions Guidelines

If you want to modify the HDL and contribute, please know that I am not interrested in major architecture modifications, i.e. pipelining, superscallar*ing* etc...

When making an RTL change to a module, make sure you run the module's testbench, eventually add testcases to the said testbench, run the HOLY CORE quick testbench and then run the riscof test suite.

More info in thr "**RTL Changes guidelines**" and "**Simulation Tips**".

Typos fix are *welcome changes*.

Docs better*ifications*, code optimisation / refoctorization or more efficient synth code structure are **very welcome** **changes**.

## Core Overview

todo : redo + add master schemes and explain

## RTL Changes guidelines

todo : talk about procdure and guive some tips

## Simulation Tips

> For advance software debugging tips when using on FPGA, see the User docs : "**Using the Fpga/ Folder to build and Debug**" Section

### Navigating and Using the tb/ Folder

Fr those who did not go through  the entire course, here is how to simulate modules and the core to validate changes

### Debugging RISCOF tests when sh*t goes south

todo : redirect to riscof readme, then explain the debug process

### Using the `fpga/` Folder to Simulate Software Execution=

The HOLY CORE codebase provides both unit testbenches