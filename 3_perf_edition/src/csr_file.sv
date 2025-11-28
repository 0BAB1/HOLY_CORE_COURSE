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

import holy_core_pkg::*;

module csr_file (
    // IN
    input logic clk,
    input logic rst_n,
    input logic stall,
    input logic [2:0] f3,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic [11:0] address,
    input logic [31:0] current_core_pc,
    input logic [31:0] anticipated_core_pc,
    input logic [31:0] current_core_fetch_instr,

    // Interrupts In
    input logic timer_itr,
    input logic soft_itr,
    input logic ext_itr,
    // Debug i/o
    input logic debug_req,
    output logic jump_to_debug,
    output logic jump_to_debug_exception,

    // from control
    input logic m_ret,
    input logic d_ret,
    input logic exception,
    input logic [30:0] exception_cause,

    // computed target addresses from execution stage
    // this type simple cacontenates both targets from the
    // ALU (loads/stores) and second adder (branches/jumps)
    // and is used to fill mtval in case of a misaligned j/b
    input target_addr exception_target_addr,

    // OUT DATA
    output logic [31:0] read_data,

    // OUT CSR SIGNALS
    // Custom cache control
    output logic flush_cache_flag,
    output logic [31:0]  data_non_cachable_base_o,
    output logic [31:0]  data_non_cachable_limit_o,
    output logic [31:0]  instr_non_cachable_base_o,
    output logic [31:0]  instr_non_cachable_limit_o,

    // Trap handling
    output logic trap,
    output logic [31:0] csr_mtvec,
    output logic [31:0] csr_mepc,

    // Debug pc for exiting debug mode
    output logic [31:0] csr_dpc,
    // Are we single stepping ?
    output logic        single_step
);

/*  
========= Message from BRH :
    Design choice : we declare each CSR individually instead of declaring a whole
    addresable BRAM array (4096 regs..) which would waste space. I don't really know
    If that really saves space but I did it so its too late mouhahaha.
=========
*/

// Output signals assigns
assign csr_mtvec = mtvec;
assign csr_mepc  = mepc;
assign csr_dpc = dpc;
assign single_step = dcsr[2];

// Declare all CSRs and they next signals here

// Trap handling standard C&S registers
logic [31:0] mstatus, next_mstatus;             // 0x300
logic [31:0] misa, next_misa;                   // 0x301
logic [31:0] mie, next_mie;                     // 0x304
logic [31:0] mip, next_mip;                     // 0x344
logic [31:0] mtvec, next_mtvec;                 // 0x305
logic [31:0] mepc, next_mepc;                   // 0x341
logic [31:0] mcause, next_mcause;               // 0x342
logic [31:0] mscratch, next_mscratch;           // 0x340
logic [31:0] mtval, next_mtval;                 // 0x343

// Debug CSRs (Execution based implementation)
// See : https://github.com/pulp-platform/riscv-dbg/blob/master/doc/debug-system.md
logic [31:0] dcsr, next_dcsr;                   // 0x7b0
logic [31:0] dpc, next_dpc;                     // 0x7b1
logic [31:0] dscratch0, next_dscratch0;         // 0x7b2
logic [31:0] dscratch1, next_dscratch1;         // 0x7b2

// Custom CSRs to controle cache behavior (if cache is enabled)
logic [31:0] flush_cache, next_flush_cache;                           // 0x7C0
logic [31:0] data_non_cachable_base, next_data_non_cachable_base;     // 0x7C1
logic [31:0] data_non_cachable_limit, next_data_non_cachable_limit;   // 0x7C2
logic [31:0] instr_non_cachable_base, next_instr_non_cachable_base;     // 0x7C3
logic [31:0] instr_non_cachable_limit, next_instr_non_cachable_limit;   // 0x7C4

// trap_taken state register
logic trap_taken; // 1 if currently handling a trap

// degub_mode state trap register
logic debug_mode; // 1 if currently debugging

always_ff @(posedge clk) begin
    if(~rst_n) begin
        // Customs
        flush_cache         <= 32'd0;
        // nothing is cachable by default, except RAM.
        data_non_cachable_base      <= 32'd0;
        data_non_cachable_limit     <= 32'h7FFFFFFF;
        instr_non_cachable_base     <= 32'd0;
        instr_non_cachable_limit    <= 32'h7FFFFFFF;

        // Trap handling
        mstatus             <= 32'h00001800;
        mie                 <= 32'd0;
        mip                 <= 32'd0;
        mtvec               <= 32'd0;
        mepc                <= 32'd0;
        mcause              <= 32'd0;
        mscratch            <= 32'd0;
        misa                <= 32'h40140100;
        mtval               <= 32'd0;
        // Debug
        dcsr                <= 32'd0;
        dpc                 <= 32'd0;
        dscratch0           <= 32'd0;
        dscratch1           <= 32'd0;
        debug_mode          <= 1'b0;
        // Indicators
        trap_taken          <= 1'b0;
    end
    else begin
        // Customs
        flush_cache                 <= next_flush_cache;
        data_non_cachable_base      <= next_data_non_cachable_base;
        data_non_cachable_limit     <= next_data_non_cachable_limit;
        instr_non_cachable_base     <= next_instr_non_cachable_base;
        instr_non_cachable_limit    <= next_instr_non_cachable_limit;
        // Trap handling
        mstatus             <= next_mstatus;
        mie                 <= next_mie;
        mip                 <= next_mip;
        mtvec               <= next_mtvec;
        mepc                <= next_mepc;
        mcause              <= next_mcause;
        mscratch            <= next_mscratch;
        misa                <= next_misa;
        mtval               <= next_mtval;
        // Debug
        dcsr                <= next_dcsr;
        dpc                 <= next_dpc;
        dscratch0           <= next_dscratch0;
        dscratch1           <= next_dscratch1;

        // Trap seq logic
        trap_taken <= trap_taken;
        if(trap)        trap_taken <= 1'b1;
        else if(m_ret)  trap_taken <= 1'b0;

        // Debug mode seq logic
        if(jump_to_debug) begin
            debug_mode <= 1;
        end else if(d_ret) begin
            debug_mode <= 0;
        end else begin
            debug_mode <= debug_mode;
        end
    end
end

// =====================
//  CSRs main logic
// =====================

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
    end else if (~stall && write_enable & (address == 12'h300)) begin
        next_mstatus = write_back_to_csr;
    end

    // mie
    next_mie = mie;
    if (~stall && write_enable && (address == 12'h304)) begin
        next_mie = write_back_to_csr;
    end

    // mip
    next_mip = (32'(soft_itr) << 3) | (32'(timer_itr) << 7) | (32'(ext_itr) << 11);

    // mtvec
    next_mtvec = mtvec;
    if (~stall && write_enable && (address == 12'h305)) begin
        next_mtvec = write_back_to_csr;
    end

    // mepc
    next_mepc = mepc;
    if (trap) begin
        next_mepc = current_core_pc;
    end else if (~stall && write_enable && (address == 12'h341)) begin
        next_mepc = write_back_to_csr;
    end

    //mscratch
    next_mscratch = mscratch;
    if (~stall && write_enable && (address == 12'h340)) begin
        next_mscratch = write_back_to_csr;
    end

    //misa 
    next_misa = misa; //(RO and fixed on reset)

    //mtval
    next_mtval = mtval;
    if(trap && exception)begin
        case (exception_cause)
            // todo : set these values as params in pkg file...
            31'd0:  next_mtval = exception_target_addr.second_adder_addr; // misaligned j/b target
            31'd2:  next_mtval = current_core_fetch_instr;          // illegal instr
            31'd4:  next_mtval = exception_target_addr.alu_addr;    // misaligned load target
            31'd6:  next_mtval = exception_target_addr.alu_addr;    // misaligned store target
            31'd3:  next_mtval = current_core_pc;                   // ebreak
            31'd11: next_mtval = 32'd0;                             // ecall
            default:next_mtval = mtval;
        endcase
    end else if (~stall && write_enable && (address == 12'h343)) begin
        next_mtval = write_back_to_csr;
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
                next_mcause[30:0] = 31'd11;
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
    // DEBUG CSRS

    // dcsr
    next_dcsr = dcsr;
    if (~stall && write_enable && (address == 12'h7b0)) begin
        next_dcsr = write_back_to_csr;
    end
    if (jump_to_debug || jump_to_debug_exception) begin
        // set cause when we are about to jump to debug mode

        /* Explains why Debug Mode was entered.
        *  When there are multiple reasons to enter Debug
        *  Mode in a single cycle, hardware should set cause
        *  to the cause with the highest priority.
        *  1: An ebreak instruction was executed. (priority
        *  3)
        *  2: The Trigger Module caused a breakpoint ex-
        *  ception. (priority 4, highest)
        *  3: The debugger requested entry to Debug Mode
        *  using haltreq. (priority 1)
        *  4: The hart single stepped because step was set.
        *  (priority 0, lowest)
        *  5: The hart halted directly out of reset due to
        *  resethaltreq. It is also acceptable to report 3 when
        *  this happens. (priority 2) TODO : implement that
        *  Other values are reserved for future use.
        */

        // Note: This core only supports execution based
        // debugging, meaning we don't need "trigger module"
        // cause support.

        if (breakpoint_detected) begin
            next_dcsr[8:6] = 2;
        end else if (debug_exception_detected) begin
            next_dcsr[8:6] = 1;
        end else if (0) begin 
            // TODO : reserved for future rest halt req support
        end else if (~debug_exception_detected && ~single_step) begin
            next_dcsr[8:6] = 3;
        end else if (single_step) begin
            next_dcsr[8:6] = 4;
        end
    end

    // dpc
    next_dpc = dpc;
    if (~stall && jump_to_debug && ~debug_exception_detected) begin 
        // Note: if we jump back because of an ebreak, dpc shall not change
        if(~single_step) begin
            next_dpc = current_core_pc;
        end else begin
            next_dpc = anticipated_core_pc;
        end
    end
    if (~stall && write_enable && (address == 12'h7b1) && debug_mode) begin
        next_dpc = write_back_to_csr;
        // TODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODO
        // TODO : the core should trap if this is access outside of debug more
        // (in general I did not implement illegal accesses at all, or any of 
        // the privileged bs.. big TODO here !)
        // TODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODOTODO
    end
    

    // dscratch0
    next_dscratch0 = dscratch0;
    if (~stall && write_enable && (address == 12'h7b2)) begin
        next_dscratch0 = write_back_to_csr;
    end

    // dscratch1
    next_dscratch1 = dscratch1;
    if (~stall && write_enable && (address == 12'h7b3)) begin
        next_dscratch1 = write_back_to_csr;
    end

    // ----------------------------
    // Flush cache custom CSRs

    if(flush_cache_flag) begin
        next_flush_cache = 32'd0; // if we sent the flush flag, reset on the next cycle
    end
    else if (~stall && write_enable && (address == 12'h7C0))begin
        next_flush_cache = write_back_to_csr;
    end
    else begin
        next_flush_cache = flush_cache;
    end

    // ----------------------------
    // cachable base and limit CSR

    next_data_non_cachable_base = data_non_cachable_base;
    if (~stall && write_enable && (address == 12'h7C1)) begin
        next_data_non_cachable_base = write_back_to_csr;
    end

    next_data_non_cachable_limit = data_non_cachable_limit;
    if (~stall && write_enable && (address == 12'h7C2)) begin
        next_data_non_cachable_limit = write_back_to_csr;
    end

    next_instr_non_cachable_base = instr_non_cachable_base;
    if (~stall && write_enable && (address == 12'h7C3)) begin
        next_instr_non_cachable_base = write_back_to_csr;
    end

    next_instr_non_cachable_limit = instr_non_cachable_limit;
    if (~stall && write_enable && (address == 12'h7C4)) begin
        next_instr_non_cachable_limit = write_back_to_csr;
    end
end

// Always output the CSR data at the given address (or 0)
always_comb begin : csr_read_logic
    case (address)
        // Traps CSRs read out
        12'h300: read_data = mstatus;
        12'h301: read_data = misa;
        12'h304: read_data = mie;
        12'h344: read_data = mip;
        12'h305: read_data = mtvec;
        12'h340: read_data = mscratch;
        12'h341: read_data = mepc;
        12'h342: read_data = mcause;
        12'h343: read_data = mtval;

        // Custom CSRs read out
        12'h7C0: read_data = flush_cache;
        12'h7C1: read_data = data_non_cachable_base;
        12'h7C2: read_data = data_non_cachable_limit;
        12'h7C3: read_data = instr_non_cachable_base;
        12'h7C4: read_data = instr_non_cachable_limit;

        // Debug CSRs readout
        12'h7B0: read_data = dcsr;
        12'h7B1: read_data = dpc;
        12'h7B2: read_data = dscratch0;
        12'h7B3: read_data = dscratch1;

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
logic debug_exception_detected;
logic breakpoint_detected;

always_comb begin : control_assignments
    // Cache control logic
    flush_cache_flag        = flush_cache[0];
    // data caching ranges
    data_non_cachable_base_o = data_non_cachable_base;
    data_non_cachable_limit_o = data_non_cachable_limit;
    // instr caching ranges
    instr_non_cachable_base_o = instr_non_cachable_base;
    instr_non_cachable_limit_o = instr_non_cachable_limit;

    // Debug logic
    // If a trap is being handled, we shall not enter debug mode yet.
    // Exception in debug mode goto debug' excpetion handler.
    // In debug mode, an expected ebreak (exc. cause = 3) will re-enter debug (not goto debug exception handler)
    // If dscr's ebreak<m|u|s> is set (bits 12,13 or 15), the csr_file file flag this as a jump to debug as this is a GDB breakpoint outside debug mode.
    //
    // Note : i know the logic below is a mess but I had to tinker around, feel free to simplify but youll have to TEST debug features MANUALLY
    // and back it up for the chages to ba accepted. 
    debug_exception_detected = exception & debug_mode & ~stall;
    breakpoint_detected = exception && |(dcsr[15:12]) && (exception_cause == 31'd3) && ~debug_mode;

    jump_to_debug = (~trap_taken & debug_req & ~debug_mode & ~stall) | (debug_exception_detected & (exception_cause == 31'd3)) | (single_step && ~debug_mode && ~stall) | breakpoint_detected;
    jump_to_debug_exception = debug_exception_detected & (exception_cause != 31'd3);

    // Trap logic
    // We cannot start a trap if we are debuging or about to enter debug mode !
    // e.g. jump_to_debug resulting from a debug request 
    // will always have a priority !
    trap = (((| (mie & mip)) && mstatus[3]) || exception) & ~trap_taken & ~debug_mode & ~jump_to_debug;
end

endmodule