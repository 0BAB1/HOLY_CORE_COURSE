module cpu (
    input logic clk,
    input logic rst_n
);

/**
* PROGRAM COUNTER
*/

reg [31:0] pc;
always @(posedge clk) begin
    if(rst_n == 0) begin
        pc <= 32'b0;
    end else begin
        pc <= pc + 4;
    end
end

/**
* INSTRUCTION MEMORY
*/

// We do not use write for insructions, it acts as a ROM.
wire [31:0] instruction;
memory instruction_memory (
    // Memory inputs
    .clk(clk),
    .address(pc),
    .write_data(32'b0),
    .write_enable(1'b0),
    .rst_n(rst_n),

    // Memory outputs
    .read_data(instruction)
);

/**
* CONTROL
*/

/**
* REGFILE
*/

wire [4:0] source_reg1;
assign source_reg1 = instruction[19:15];

wire [31:0] read_reg1;

regfile regfile(
    // basic signals
    .clk(clk),
    .rst_n(rst_n),

    // Read In
    .address1(source_reg1),
    .address2(source_reg2),
    // Read out
    .read_data1(read_reg1),
    .read_data2(read_reg2),

    // Write In
    .write_enable(we_reg),
    .write_data(write_data_reg),
    .address3(write_dest_reg)
)

/**
* SIGN EXTEND
*/

/**
* ALU
*/

/**
* DATA MEMORY
*/
    
endmodule