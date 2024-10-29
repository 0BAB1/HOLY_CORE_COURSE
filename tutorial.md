# Tutorial / Writeup

> Tutorial heavily based on [DDCA lectures, chapter 7](https://www.youtube.com/watch?v=lrN-uBKooRY&list=PLh8QClfSUTcbfTnKUz_uPOn-ghB4iqAhs). PS :  the intro is legendary.

## 1 : Implementinge the "load word" instruction

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

|         | IMM [11:0]   | rs1          | f3                                            | rd           | op           |
| ------- | ------------ | ------------ | --------------------------------------------- | ------------ | ------------ |
| binary  | 111111111100 | 01001        | 010                                           | 00110        | 0000011      |
| Value   | -4           | 9 (as in x9) | 2 (lw)                                        | 6 (as in x6) | I-type       |

## 1.1 : What do we need

Before doing any actual hardware digital interpretation of this instruction, the lecture tells us what we need first :

- A register file
- An instruction memory
- Some data memory too

Gotta build it then !

## 1.1.a : Implementing memory

**code**

Memory is memory, on FPGA for example, we would just take everything from a DDR IP of some sort. Here we'll implement some basic piece of memory that can store X amount of words and it will respond in 1 clock cycle (which is way too good to be true, but memory is a pain so we'll *conviniently* ignore that for now...).

So, let's get to work shall we ? We create a memeory.sv file in which we'll write some [code](./src/memory.sv) :

```sv
module memory #(
    parameter WORDS = 64,
    parameter ADDR_WIDTH = $clog2(WORDS)
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic rst_n,

    output logic [31:0] read_data
);

reg [31:0] mem [0:WORDS-1];

always @(posedge clk ) begin
    // reset support, init to 0
    if(rst_n == 1'b0) begin
        for(int i = 0; i<WORDS; i++) begin
            mem[i] <= 32'b0;
        end
    end 
    else if(write_enable == 1'b1) begin
        mem[address] <= write_data;
    end

    read_data <= mem[address];
end
  
endmodule
```

Nothing fancy if not the parameters. If you know your way around HDL, this should be farly easy for you, If not, se this as a big addressed register, I suggest you use an LLM to explain things you don't get when I go over them too quickly.

Each and everytime we implement something, we also test it, as stated in the main [readme file](./readme.md), we will use cocotb and verilator to verify our HDL.

**verification**

When it comes to verifying memory, we'll simply do some writes while tinkering with the ``write_enable`` flag. Since I don't like writing tests and this is a simple case, I can ask my favorite LLM to generate some tests for me and after manual review, here is the testbench :

```python
# à completer
```

## 1.1.b : Implementing the regfile

**Code**

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

**Verification**

Now to verify this HDL, we'll simply 