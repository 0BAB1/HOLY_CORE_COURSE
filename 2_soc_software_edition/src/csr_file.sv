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

    // OUT DATA
    output logic [31:0] read_data,

    // OUT CSR SIGNALS
    output logic flush_cache_flag,
    output logic [31:0]  non_cachable_base_addr,
    output logic [31:0]  non_cachable_limit_addr
);

/*  
========= Message from BRH :
    Design choice : we declare each CSR individually instead of declaring a whole
    addresable BRAM array (4096 regs..) which would waste space. I don't really know
    If that really saves space but I did it so its too late mouhahaha.
=========
*/

// Declare all CSRs and they next signals here
logic [31:0] flush_cache, next_flush_cache;                 // 0x7C0
logic [31:0] non_cachable_base, next_non_cachable_base;     // 0x7C1
logic [31:0] non_cachable_limit, next_non_cachable_limit;   // 0x7C2

always_ff @(posedge clk) begin
    if(~rst_n) begin
        flush_cache <= 32'd0;
        non_cachable_base <= 32'd0;
        non_cachable_limit <= 32'd0;
    end
    else begin
        flush_cache <= next_flush_cache;
        non_cachable_base <= next_non_cachable_base;
        non_cachable_limit <= next_non_cachable_limit;
    end
end

// Specific CSRs logics
always_comb begin
    // ----------------------------
    // Flush cache CSR

    if(flush_cache_flag) begin
        next_flush_cache = 32'd0; // if we sent the flush flag, reset on the next cycle
    end
    else if (write_enable & (address == 12'h7C0))begin
        next_flush_cache = write_back_to_csr;
    end
    else begin
        next_flush_cache = flush_cache;
    end

    // ----------------------------
    // cachable base and limit CSR

    next_non_cachable_base = non_cachable_base;
    if (write_enable & (address == 12'h7C1)) begin
        next_non_cachable_base = write_back_to_csr;
    end

    next_non_cachable_limit = non_cachable_limit;
    if (write_enable & (address == 12'h7C2)) begin
        next_non_cachable_limit = write_back_to_csr;
    end
end

// Always output the CSR data at the given address (or 0)
always_comb begin
    case (address)
        12'h7C0: read_data = flush_cache;
        12'h7C1: read_data = non_cachable_base;
        12'h7C2: read_data = non_cachable_limit;
        default: read_data = 32'd0;
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
            write_back_to_csr = 32'd0;
        end
    endcase
end

// output control signals
always_comb begin : control_assignments
    flush_cache_flag = flush_cache[0];
    non_cachable_base_addr = non_cachable_base;
    non_cachable_limit_addr = non_cachable_limit;
end

endmodule