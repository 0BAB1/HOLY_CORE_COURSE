# Tutorial / Writeup

> Tutorial heavily based on [DDCA lectures, chapter 7](https://www.youtube.com/watch?v=lrN-uBKooRY&list=PLh8QClfSUTcbfTnKUz_uPOn-ghB4iqAhs). PS :  the intro is legendary.

## 1 : Implementinge th "load word" instruction

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

|  | IMM [11:0] | rs1 | f3 | rd | op |
|---|---|---|---|---|---|
| binary | 111111111100 | 01001 | 010 |  |  |
| decimal | -4 | 9 (as in x9) | 2 (just to specify the instruction "variant") | 6 (as in x6) | 0000011 (lw) |

### What do we need

Before doing any actual hardware digital interpretation of this instruction, the lecture tells us what we need first :

- A register file
- An instruction memory
- Some data memory too

Gotta build it then !

#### Implementing memory

Memory is memory, on FPGA for example, we would just take everything from a DDR IP of some sort. Here we'll implement some basic piece of memory that can store X amount of words and it will respond in 1 clock cycle (which is way too good to be true, but memory is a pain so we'll *conviniently* ignore that for now...).

So, let's get to work shall we ? We create a memeory.sv file in which we'll write some [code](./src/memory.sv) :

```sv
module moduleName #(
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

#### Implementing the regfile

For the reg file, it's just 32x32bits registers.