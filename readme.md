# HOLY CORE COURSE PROJECT

An open-source core **for learning purposes**. Learn to build your own 32 bits RISC-V core with detailled tutorials as a reference.

The course is divided in multiple blocks to learn different aspects of digital design. The table below indicates availability of these learning blocks.

> The code will always be **open-source** But some materials might be paid, especially for the more advanced course.

| Block Name            | Markdown tutorial     | PDF tutorial  | Status            |
| ----------            | -----------------     | ------------  | ------            |
| Single cycle edition  | Free & Open source    | Paid          | FINISHING PHASE   |
| FPGA edition          |                       |               | BUILDING PHASE    |
| Pipelined edition     |                       |               | NOT STARTED       |

## Prerequestites

To start this course you need to have these basics down :

- Python programming.
- RISC-V assembly.
- SystemVerilog / HDL knowledge.
- Have a linux distro

> **Please check out the [setup](./setup.md) before starting the course !** Use it to setup you environement properly. You can also keep it neer beacause it contains various information regarding testing that will be useful in the later stages of the course.

## The tutorials

Before diving into the tutorials, it is **mandatory** to setup your environement correctly first using the guidelines below.

If you already did that, know that the repo is organized in branches, one per block. The first block's tutorial (single cycle RV32I) is completely free in *MarkDown* format but you can buy the PDF edition to support me (it contains more details, my own notes and some personal easter eggs too ;p). Other blocks are paid but you can still access the source code if you want.

So, once the setup is done, you can read the course summary below and open the PDF of the block you want to build or access the first tutorial for free [here](./tutorial.md).

## Course summary

What can you learn from the differents course block ?

### Single cycle edition

Learn to implement the full RV32I instruction set from scratch.

**Goal :** Get a RISC-V program to run ont the core through simulation. The core is 100% custom logic, from scratch.

- Build the different logic blocks and assemble them to implement your first instruction : ```lw```
- Improve the design to implement more and more instructions
- Build simple test benches to test your logic and learn a basic design/test workflow.

You will build the logic blocks yourself in **systemVerilog** and test them using **cocotb**. You can follow along the tutorial for reference but as long as the logic works, you can do you own logic and tinker around !

### FPGA Edition

Take a deep dive into memory.

**Goal :** Implement the core on FPGA and leverage systemVerilog capabilities to :

- Add interfaxce to interact with the "outside" world
- Improve our design by using cache and querying external data using AXI.
- Interact with I/Os

### Pipelined edition

Make the core more performant by adding a pipeline.

**Goal :** Increase the core perfs by pipelining it and hadling all the hazards that comes with it.

<!-- Still not sure I'll do that though -->

### FPGA edition

## A word on the course

The HOLY CORE is a project I started for my own learning journey and I documented by explaining what I do to... :

- ...Make my own understading clearer
- ...Make the whole thing availible once I'm done

So yes, it was made **by** a "begginer" **for** begginers. If your nerdy self decides something is "wrong" in the way I decided to conduct my (Holy) operations, I suggest you re-consider the fact of complaining for better activities like : *touching grass* or *going for a walk outside* for example.

Nevertheless, I am still very open to meaningful and constructive criticism, in which case I will be more than happy to consider you opinion.