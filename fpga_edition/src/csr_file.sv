/*
* HOLY CORE Control Status Register FILE
*
* BRH 05/25
*
* CSR File to implement Zicsr & Zicntr
*/

`timescale 1ns/1ps

module csr_file (
    // IN
    input logic clk,
    input logic rst_n,
    input logic [2:0] f3,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic [11:0] address,

    // OUT
    output logic flush_cache_flag,
    output logic [31:0] read_data
);

/*
    Design choice : we declare each CSR individually instead of declaring a whole
    addresable BRAM array (4096 regs..) which would waste space. I don't really know
    If that really saves space but I did it so its too late mouhahaha.
*/

logic [31:0] flush_cache;

always_ff @(posedge clk) begin
    if(~rst_n) begin
        flush_cache <= 32'b0;
    end
    else if (write_enable) begin
        case (address)
            12'h7C0: flush_cache <= write_back_to_csr;
            default: ; // do nothing
        endcase
    end
end

// Always output the CSR data at the given address (or 0)
always_comb begin
    case (address)
        12'h7C0: read_data = flush_cache;
        default: read_data = '0;
    endcase
end

// Compute next CSR possible values
logic [31:0] or_result;
logic [31:0] nand_result;

always_comb begin
    or_result = write_data | read_data;
    nand_result = read_data & (~write_data);
end

// Select value using F3
logic [31:0] write_back_to_csr;

always_comb begin
    case (f3)
        3'b001, 3'b101 : write_back_to_csr = write_data;

        3'b010, 3'b110 : write_back_to_csr = or_result;

        3'b011, 3'b111 : write_back_to_csr = nand_result;

        default : begin
            write_back_to_csr = 0;
        end
    endcase
end

// output control signals
always_comb begin : control_assignments
    flush_cache_flag = flush_cache[0];
end

endmodule