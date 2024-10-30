# Tutorial / Writeup

Tutorial heavily based on [DDCA lectures, chapter 7](https://www.youtube.com/watch?v=lrN-uBKooRY&list=PLh8QClfSUTcbfTnKUz_uPOn-ghB4iqAhs). PS :  the intro is legendary.

Here is what we'll aim to build in this tutorial :

![finished single cycle](./Complete_single_cycle.png)

In order to achieve this, we'll (more or less) follow the [DDCA lectures, chapter 7](https://www.youtube.com/watch?v=lrN-uBKooRY&list=PLh8QClfSUTcbfTnKUz_uPOn-ghB4iqAhs) lectures (availible for free on youtube).

The method consist in thinking about each kind of instruction we can encounter and implement the necessary building block whilst thinking about the datapath.

Of course, the first instruction will necessitate the most as we'll start from 0.

## 1 : Implementing the "load word" instruction

[Lecture](https://www.youtube.com/watch?v=AoBkibslRBM)

Load word : lw

Here is an example that loads data into reg x6, from the pointer in x9 with an offset of -4 on the address :

```asm
lw x6, -4(x9)
```

We would translate it like this in binary and in hex, as an I-type instruction :

```txt
111111111100 01001 010 00110 0000011
0xFFC4A303
```

here is a quick breakdown :

|        | IMM [11:0]   | rs1          | f3     | rd           | op      |
| ------ | ------------ | ------------ | ------ | ------------ | ------- |
| binary | 111111111100 | 01001        | 010    | 00110        | 0000011 |
| Value  | -4           | 9 (as in x9) | 2 (lw) | 6 (as in x6) | I-type  |

## 1.1 : What do we need

Before doing any actual hardware digital interpretation of this instruction, the lecture tells us what we need first :

- A register file
- An instruction memory
- Some data memory too
- A sign extender
- A basic ALU we'll improve as time goes on
- And a decoder/control unit we will improve as time goes on

Gotta build it then ! We'll start by crezting basic versions of the different building blocks, test them seperatly and assemble them.

## 1.1.a : Implementing memory

### HDL Code

Memory is memory, on FPGA for example, we would just take everything from a DDR IP of some sort. Here we'll implement some basic piece of memory that can store X amount of words and it will respond in 1 clock cycle (which is way too good to be true, but memory is a pain so we'll *conviniently* ignore that for now...).

So, let's get to work shall we ? We create a memeory.sv file in which we'll write some [code](./src/memory.sv) :

```sv
module memory #(
    parameter WORDS = 64
) (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic rst_n,

    output logic [31:0] read_data
);

/*
* This memory is byte addressed
* But have no support for mis-aligned write nor reads.
*/

reg [31:0] mem [0:WORDS-1];  // Memory array of words (32-bits)

always @(posedge clk) begin
    // reset logic
    if (rst_n == 1'b0) begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] <= 32'b0;  
        end
    end
    else if (write_enable) begin
        // Ensure the address is aligned to a word boundary
        // If not, we ignore the write
        if (address[1:0] == 2'b00) begin 
            //here, address[31:2] is the word index
            mem[address[31:2]] <= write_data;
        end
    end
end

// Read logic
always_comb begin
    //here, address[31:2] is the word index
    read_data = mem[address[31:2]]; 
end

endmodule
```

Note the trick here, we use a [byte adressed momory](https://youtu.be/P2oFPtdDgTg?feature=shared&t=233) (watch the video if you don't know the difference with word addressed memory). However, the memory stays fairly simple as we do not add support for non-aligned read and writes. It just add statements like ``mem[address[31:2]] <= write_data;`` which can be tricky to get your head around at first as a begginer, but do some research, take your time to understand if you don't. If you do, let's move on shall we ?
(If you know your way around HDL, this should be farly easy for you)

Each and everytime we implement something, we also test it, as stated in the main [readme file](./readme.md), we will use cocotb and verilator to verify our HDL.

### Verification

When it comes to verifying memory, we'll simply do some writes while tinkering with the ``write_enable`` flag. Since I don't like writing tests and this is a simple case, I can ask my favorite LLM to generate some tests for me and after manual review (turns out LLM are EXTREMELY bad at cocotb and hadware stuff in general), here is the testbench :

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def memory_data_test(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 1, units="ns").start())
    await RisingEdge(dut.clk)

    # Init and reset
    dut.rst_n.value = 0
    dut.write_enable.value = 0
    dut.address.value = 0
    dut.write_data.value = 0      # De-assert reset

    await RisingEdge(dut.clk)     # Wait for a clock edge after reset
    dut.rst_n.value = 1           # De-assert reset
    await RisingEdge(dut.clk)     # Wait for a clock edge after reset

    # Assert all is 0 after reset
    for address in range(dut.WORDS.value):
        dut.address.value = address
        await Timer(1, units="ns")
        # just 32 zeroes, you can also use int()
        assert dut.read_data.value == "00000000000000000000000000000000"
      
    # Test: Write and read back data
    test_data = [
        (0, 0xDEADBEEF),
        (4, 0xCAFEBABE),
        (8, 0x12345678),
        (12, 0xA5A5A5A5)
    ]

    for address, data in test_data:
        # Write data to memory
        dut.address.value = address
        dut.write_data.value = data
        dut.write_enable.value = 1
        await RisingEdge(dut.clk)

        # Disable write after one cycle
        dut.write_enable.value = 0
        await RisingEdge(dut.clk)

        # Verify the write by reading back
        dut.address.value = address
        await RisingEdge(dut.clk)
        assert dut.read_data.value == data, f"Readback error at address {address}: expected {hex(data)}, got {hex(dut.read_data.value)}"

    # Test: Write to multiple addresses, then read back
    for i in range(40,4):
        dut.address.value = i
        dut.write_data.value = i + 100
        dut.write_enable.value = 1
        await RisingEdge(dut.clk)

    # Disable write, then read back values to check
    dut.write_enable.value = 0
    for i in range(40,4):
        dut.address.value = i
        await RisingEdge(dut.clk)
        expected_value = i + 100
        assert dut.read_data.value == expected_value, f"Expected {expected_value}, got {dut.read_data.value} at address {i}"
```

Once agin, we increment memory by 4 beacause it is byte addressed.

To run this, I create a ``Makefile`` according to the [cocotb docs](https://docs.cocotb.org/en/stable/quickstart.html#creating-a-makefile) and, still in the memory tesbench subdir, I use ``gtkwave ./sim_build/memory.fst`` to visualize the waveforms. It's all open-source ! *But once again, without linux, you will have some troubles.*

After it's done, I can go back to the root dir and run ``make clean`` to clean out the simulation results.

## 1.1.b : Implementing the regfile

### HDL Code

For the reg file, it's just 32x32bits registers. we'll implement it like memory execpt the size is fixes the 32 bits with 5bits addressing.

The I/Os are a bit different though as we have to accomodate all the instrction types : in R-Types (which operates ONLY on registers) we can write to a register whilst getting data from 2 of them at the same time.

```sv
module regfile (
    // basic signals
    input logic clk,
    input logic rst_n,

    // Reads
    input logic [4:0] address1,
    input logic [4:0] address2,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2,

    // Writes
    input logic write_enable,
    input logic [31:0] write_data,
    input logic [4:0] address3
);

// 32bits register. 32 of them (addressed with 5 bits)
reg [31:0] registers [0:31]; 

// Write logic
always @(posedge clk) begin
    // reset support, init to 0
    if(rst_n == 1'b0) begin
        for(int i = 0; i<32; i++) begin
            registers[i] <= 32'b0;
        end
    end 
    // Write, except on 0, reserved for a zero constant according to RISC-V specs
    else if(write_enable == 1'b1 && address3 != 0) begin
        registers[address3] <= write_data;
    end
end

// Read logic, async
always_comb begin : readLogic
    read_data1 = registers[address1];
    read_data2 = registers[address2];
end
  
endmodule
```

### Verification

Now to verify this HDL, we'll simply use random write on A3, and read after each write on both address. We then compare to a therorical golden state update in software in the testbench.

We also add small tests at the end to test the 0 constant, It's simple but helps us getting used to cocotb.

Note that we use small timer delay to test out the async properties of our design.

```python
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import numpy as np

@cocotb.test()
async def random_write_read_test(dut):
    # Start a 10 ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await RisingEdge(dut.clk)

    # Init and reset
    dut.rst_n.value = 0
    dut.write_enable.value = 0
    dut.address1.value = 0
    dut.address2.value = 0
    dut.address3.value = 0
    dut.write_data.value = 0  

    await RisingEdge(dut.clk)   
    dut.rst_n.value = 1  # realease reset_n   
    await RisingEdge(dut.clk)  

    # fill a heorical state of the regs, all 0s for starters
    theorical_regs = [0 for _ in range(32)]

    # Loop to write and read random values, 1000 test shall be enough
    for _ in range(1000): 
        # Generate a random register address (1 to 31, skip 0)
        address1 = random.randint(1, 31)
        address2 = random.randint(1, 31)
        address3 = random.randint(1, 31)
        write_value = random.randint(0, 0xFFFFFFFF)

        # perform reads
        await Timer(1, units="ns") # wait a ns to test async read
        dut.address1.value = address1
        dut.address2.value = address2
        await Timer(1, units="ns")
        assert dut.read_data1.value == theorical_regs[address1]
        assert dut.read_data2.value == theorical_regs[address2]

        # perform a random write
        dut.address3.value = address3
        dut.write_enable.value = 1
        dut.write_data = write_value
        await RisingEdge(dut.clk)
        dut.write_enable.value = 0
        theorical_regs[address3] = write_value
        await Timer(1, units="ns")

    # try to write at 0 and check if it's still 0
    await Timer(1, units="ns")
    dut.address3.value = 0
    dut.write_enable.value = 1
    dut.write_data = 0xAEAEAEAE
    await RisingEdge(dut.clk)
    dut.write_enable.value = 0
    theorical_regs[address3] = 0

    await Timer(1, units="ns") # wait a ns to test async read
    dut.address1.value = 0
    await Timer(1, units="ns")
    print(dut.read_data1.value)
    assert int(dut.read_data1.value) == 0

    print("Random write/read test completed successfully.")
```

## 1.1.c Implementing the ALU

