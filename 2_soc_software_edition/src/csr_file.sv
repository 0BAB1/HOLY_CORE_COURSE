/** CSR File
*
*   Author : BRH
*   Project : Holy Core Fpga_edition
*   Description : A simple CSR file for the HOLY CORE.
*                 It handles trap requests (need cpu hints, given by
*                 control in HOLY CORE).
*                 It also features custom cache behavior control CSRs.
*
*   Created 05/25
*   TODO : make addresses paramrs (in pkg or local idc)
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
    input logic [31:0] current_core_pc,

    // Interrupts In
    input logic timer_itr,
    input logic soft_itr,
    input logic ext_itr,

    // from control
    input logic m_ret,
    input logic exception,
    input logic [30:0] exception_cause,

    // OUT DATA
    output logic [31:0] read_data,

    // OUT CSR SIGNALS

    // Custom cache control
    output logic flush_cache_flag,
    output logic [31:0]  non_cachable_base_addr,
    output logic [31:0]  non_cachable_limit_addr,

    // Trap handling
    output logic trap
);

/*  
========= Message from BRH :
    Design choice : we declare each CSR individually instead of declaring a whole
    addresable BRAM array (4096 regs..) which would waste space. I don't really know
    If that really saves space but I did it so its too late mouhahaha.
=========
*/

// Declare all CSRs and they next signals here

// Trap handling standard C&S registers
logic [31:0] mstatus, next_mstatus;             // 0x300
logic [31:0] mie, next_mie;                     // 0x304
logic [31:0] mip, next_mip;                     // 0x344
logic [31:0] mtvec, next_mtvec;                 // 0x305
logic [31:0] mepc, next_mepc;                   // 0x341
logic [31:0] mcause, next_mcause;               // 0x342

// Custom CSRs to controle cache behavior (if cache is enabled)
logic [31:0] flush_cache, next_flush_cache;                 // 0x7C0
logic [31:0] non_cachable_base, next_non_cachable_base;     // 0x7C1
logic [31:0] non_cachable_limit, next_non_cachable_limit;   // 0x7C2

// trap_taken state register
logic trap_taken;

always_ff @(posedge clk) begin
    if(~rst_n) begin
        // Customs
        flush_cache         <= 32'd0;
        non_cachable_base   <= 32'd0;
        non_cachable_limit  <= 32'd0;
        // Trap handling
        mstatus             <= 32'd0;
        mie                 <= 32'd0;
        mip                 <= 32'd0;
        mtvec               <= 32'd0;
        mepc                <= 32'd0;
        mcause              <= 32'd0;
        trap_taken          <= 1'b0;
    end
    else begin
        // Customs
        flush_cache         <= next_flush_cache;
        non_cachable_base   <= next_non_cachable_base;
        non_cachable_limit  <= next_non_cachable_limit;
        // Trap handling
        mstatus             <= next_mstatus;
        mie                 <= next_mie;
        mip                 <= next_mip;
        mtvec               <= next_mtvec;
        mepc                <= next_mepc;
        mcause              <= next_mcause;
        
        trap_taken <= trap_taken;
        if(trap)        trap_taken <= 1'b1;
        else if(m_ret)  trap_taken <= 1'b0;
    end
end

// Specific CSRs logics
always_comb begin : next_csr_value_logic
    // ----------------------------
    // Trap CSRs

    // mstatus
    next_mstatus = mstatus;
    if(trap) begin
        next_mstatus[7] = next_mstatus[3];  // Save current IE value
        next_mstatus[3] = 0;                // Disable interrupts (IE = 0)
    end else if(m_ret)begin
        next_mstatus[3] = next_mstatus[7];  // Restore old IE when returning
    end else if (write_enable & (address == 12'h300)) begin
        next_mstatus = write_back_to_csr;
    end

    // mie
    next_mie = mie;
    if (write_enable & (address == 12'h304)) begin
        next_mie = write_back_to_csr;
    end

    // mip
    next_mip = (32'(soft_itr) << 3) | (32'(timer_itr) << 7) | (32'(ext_itr) << 11);

    // mtvec
    next_mtvec = mtvec;
    if (write_enable & (address == 12'h305)) begin
        next_mtvec = write_back_to_csr;
    end

    // mepc
    next_mepc = mepc;
    if (trap) begin
        next_mepc = current_core_pc;
    end else if (write_enable & (address == 12'h341)) begin
        next_mepc = write_back_to_csr;
    end

    // mcause
    next_mcause = mcause;
    if(trap)begin
        // interrupts have priority over excpetions

        // if its an interrupt...
        if((|(mie & mip))) begin
            next_mcause[31] = 1;
            // the order here defines priority
            if(mip[11] && mie[11])begin
                // external
                next_mcause[31] = 1;
            end
            else if(mip[7] && mie[7])begin
                // timer
                next_mcause[30:0] = 31'd7;
            end
            else if(mip[3] && mie[3])begin
                // soft
                next_mcause[30:0] = 31'd3;
            end
        end
        // or if its an exception (less priority)
        else if(exception) begin
            next_mcause[31] = 0;
            // we reuse cause given by control 
            next_mcause[30:0] = exception_cause;
        end
    end

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
always_comb begin : csr_read_logic
    case (address)
        // Traps CSRs read out
        12'h300: read_data = mstatus;
        12'h304: read_data = mie;
        12'h344: read_data = mip;
        12'h305: read_data = mtvec;
        12'h341: read_data = mepc;
        12'h342: read_data = mcause;

        // Custom CSRs read out
        12'h7C0: read_data = flush_cache;
        12'h7C1: read_data = non_cachable_base;
        12'h7C2: read_data = non_cachable_limit;

        default: read_data = 32'd0;
    endcase
end

// CSRs can be written in 3 ways :
// 1. Simple wite
// 2. OR write (set flag)
// 3. NAND Write (unset flag)
// This logic omputes next CSR WB value based on the chosen write (F3)
logic [31:0] or_result;
logic [31:0] nand_result;
logic [31:0] write_back_to_csr;

always_comb begin : csr_wb_logic
    or_result = write_data | read_data;
    nand_result = read_data & (~write_data);

    // Select value using F3
    case (f3)
        3'b001, 3'b101 : write_back_to_csr = write_data;
        3'b010, 3'b110 : write_back_to_csr = or_result;
        3'b011, 3'b111 : write_back_to_csr = nand_result;

        default : begin
            write_back_to_csr = 32'd0;
        end
    endcase
end

// Some CSRs have direct control over the core's behavior.
// This logic block outputs control signals
always_comb begin : control_assignments
    flush_cache_flag        = flush_cache[0];
    non_cachable_base_addr  = non_cachable_base;
    non_cachable_limit_addr = non_cachable_limit;
    trap = (((| (mie & mip)) && mstatus[3]) || exception) & ~trap_taken;
end

endmodule