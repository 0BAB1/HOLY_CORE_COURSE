/*
* HOLY CORE
*
* BRH 10/24
*
* holy_core cpu. A simple core to solve simple problems. Thus the holyness ;)
*
* Yea, though I walk through the valley of the shadow of death,I will fear no evil: for thou art with me; thy rod and thy staff they comfort me.
*/

`timescale 1ns/1ps

module holy_core (
    input logic clk,
    input logic rst_n,
    // AXI Interface for external requests
    axi_if.master m_axi,
    axi_lite_if.master m_axi_lite,

    // OUTGOING DEBUG SIGNALS
    output logic [31:0] debug_pc,  
    output logic [31:0] debug_pc_next,
    output logic debug_pc_source,
    output logic [31:0] debug_instruction,  
    output logic [3:0] debug_i_cache_state,  
    output logic [3:0] debug_d_cache_state,
    output logic [6:0] debug_i_set_ptr,  
    output logic [6:0] debug_i_next_set_ptr,  
    output logic [6:0] debug_d_set_ptr,  
    output logic [6:0] debug_d_next_set_ptr,  
    output logic debug_i_cache_stall,  
    output logic debug_d_cache_stall,
    output logic debug_csr_flush_order,
    output logic       debug_d_cache_seq_stall,
    output logic       debug_d_cache_comb_stall,
    output logic [3:0] debug_d_cache_next_state,
    output logic [31:0] debug_mem_read,
    output logic [3:0] debug_mem_byte_en,
    output logic [31:0] debug_wb_data 
);

import holy_core_pkg::*;

/**
* FPGA Debug_out signals
*/

assign debug_pc = pc;  
assign debug_pc_next = pc_next;  
assign debug_instruction = instruction;  
assign debug_i_cache_state = i_cache_state;  
assign debug_d_cache_state = d_cache_state;  
assign debug_i_cache_stall = i_cache_stall;  
assign debug_d_cache_stall  = d_cache_stall; 
assign debug_csr_flush_order = csr_flush_order;
assign debug_pc_source = pc_source;

// others are assign directly to submodules outputs

/**
* M_AXI_ARBITRER, aka "mr l'arbitre"
*/

// note : AXI_LITE if is declared directly as output
axi_if m_axi_data();
axi_if m_axi_instr();

external_req_arbitrer mr_l_arbitre(
    .m_axi(m_axi),
    .s_axi_instr(m_axi_instr),
    .i_cache_state(i_cache_state),
    .s_axi_data(m_axi_data),
    .d_cache_state(d_cache_state)
);

/**
* PROGRAM COUNTER 
*/

reg [31:0] pc;
logic [31:0] pc_next;
logic [31:0] pc_plus_second_add;
logic [31:0] pc_plus_four;

// Stall from caches
logic stall;
logic d_cache_stall;
logic i_cache_stall;
assign stall = d_cache_stall | i_cache_stall;

always_comb begin : pc_select
    case(stall)
        1'b0 : pc_plus_four = pc + 32'd4;
        1'b1 : pc_plus_four = pc + 32'd0;
    endcase
    case (pc_source & ~stall)
        1'b0 : pc_next = pc_plus_four; // pc + 4
        1'b1 : pc_next = pc_plus_second_add;
    endcase
end

always_comb begin : second_add_select
    case (second_add_source)
        2'b00 : pc_plus_second_add = pc + immediate;
        2'b01 : pc_plus_second_add = immediate;
        2'b10 : pc_plus_second_add = read_reg1 + immediate;
        default : pc_plus_second_add = 32'd0;
    endcase
end

always @(posedge clk) begin
    if(rst_n == 0) begin
        pc <= 32'b0;
    end else begin
        pc <= pc_next;
    end
end

/**
* INSTRUCTION CACHE MEMORY
*/

// Acts as a ROM.
wire [31:0] instruction;
cache_state_t i_cache_state;

// holy_cache =/=  holy_data_cache !
holy_cache instr_cache (
    .clk(clk),
    .rst_n(rst_n),
    .aclk(m_axi.aclk),

    // CPU IF
    .address(pc),
    .write_data(32'd0),
    .read_enable(1'b1),
    .write_enable(1'b0),
    .byte_enable(4'd0),
    .csr_flush_order(1'b0),
    .read_data(instruction),
    .cache_stall(i_cache_stall),

    // M_AXI EXERNAL REQ IF
    .axi(m_axi_instr),
    .cache_state(i_cache_state),

    //debug
    .set_ptr_out(debug_i_set_ptr),
    .next_set_ptr_out(debug_i_next_set_ptr)
);

/**
* CONTROL
*/

// Intercepts instructions data, generate control signals accordignly
// in control unit
logic [6:0] op;
assign op = instruction[6:0];
logic [2:0] f3;
assign f3 = instruction[14:12];
logic [6:0] f7;
assign f7 = instruction[31:25];
wire alu_zero;
wire alu_last_bit;
// out of control unit
wire [3:0] alu_control;
wire [2:0] imm_source;
wire mem_write_enable;
wire mem_read_enable;
wire reg_write;
// out muxes wires
wire alu_source;
wire [2:0] write_back_source;
wire pc_source;
wire [1:0] second_add_source;
wire csr_write_back_source;

control control_unit(
    .op(op),
    .func3(f3),
    .func7(f7), // we still don't use f7 (YET)
    .alu_zero(alu_zero),
    .alu_last_bit(alu_last_bit),

    // OUT
    .alu_control(alu_control),
    .imm_source(imm_source),
    .mem_write(mem_write_enable),
    .mem_read(mem_read_enable),
    .reg_write(reg_write),
    .csr_write_back_source(csr_write_back_source),
    .csr_write_enable(csr_write_enable),
    // muxes out
    .alu_source(alu_source),
    .write_back_source(write_back_source),
    .pc_source(pc_source),
    .second_add_source(second_add_source)
);

/**
* REGFILE
*/

logic [4:0] source_reg1;
assign source_reg1 = instruction[19:15];
logic [4:0] source_reg2;
assign source_reg2 = instruction[24:20];
logic [4:0] dest_reg;
assign dest_reg = instruction[11:7];
wire [31:0] read_reg1;
wire [31:0] read_reg2;
logic wb_valid;

logic [31:0] write_back_data;
always_comb begin : write_back_source_select
    case (write_back_source)
        3'b000: begin
            write_back_data = alu_result;
            wb_valid = 1'b1;
        end
        3'b001: begin
            write_back_data = mem_read_write_back_data;
            wb_valid = mem_read_write_back_valid;
        end
        3'b010: begin
            write_back_data = pc_plus_four;
            wb_valid = 1'b1;
        end
        3'b011: begin
            write_back_data = pc_plus_second_add;
            wb_valid = 1'b1;
        end
        3'b100: begin
            write_back_data = csr_read_data;
            wb_valid = 1'b1;
        end
        default begin
            write_back_data = 32'hFFFFFFFF;
            wb_valid = 1'b0;
        end
    endcase
end

regfile regfile(
    // basic signals
    .clk(clk),
    .rst_n(rst_n | m_axi.aresetn),

    // Read In
    .address1(source_reg1),
    .address2(source_reg2),
    // Read out
    .read_data1(read_reg1),
    .read_data2(read_reg2),

    // Write In
    .write_enable(reg_write & wb_valid),
    .write_data(write_back_data),
    .address3(dest_reg)
);

/**
* SIGN EXTEND
*/
logic [24:0] raw_imm;
assign raw_imm = instruction[31:7];
wire [31:0] immediate;

signext sign_extender(
    .raw_src(raw_imm),
    .imm_source(imm_source),
    .immediate(immediate)
);

/**
* CSR REGFILE
*/

logic [31:0] csr_write_back_data;
logic [31:0] csr_write_data;
always_comb begin : csr_wb_mux
    if(~csr_write_back_source) begin
        csr_write_back_data = read_reg1;
    end else begin
        csr_write_back_data = immediate;
    end
end

logic [11:0] csr_address;
assign csr_address = instruction[31:20];
logic [31:0] csr_read_data;
logic csr_write_enable;

// csr orders
logic csr_flush_order;
logic [31:0] csr_non_cachable_base;
logic [31:0] csr_non_cachable_limit;

csr_file holy_csr_file(
    //in
    .clk(clk),
    .rst_n(rst_n),
    .f3(f3),
    .write_data(csr_write_back_data),
    .write_enable(csr_write_enable),
    .address(csr_address),
    //out
    .read_data(csr_read_data),
    .flush_cache_flag(csr_flush_order),
    .non_cachable_base_addr(csr_non_cachable_base),
    .non_cachable_limit_addr(csr_non_cachable_limit)
);

/**
* ALU
*/
wire [31:0] alu_result;
logic [31:0] alu_src2;

always_comb begin : alu_source_select
    case (alu_source)
        1'b1: alu_src2 = immediate;
        default: alu_src2 = read_reg2;
    endcase
end

alu alu_inst(
    .alu_control(alu_control),
    .src1(read_reg1),
    .src2(alu_src2),
    .alu_result(alu_result),
    .zero(alu_zero),
    .last_bit(alu_last_bit)
);

/**
* LOAD/STORE DECODER
*/

wire [3:0] mem_byte_enable;
wire [31:0] mem_write_data;

load_store_decoder ls_decode(
    .alu_result_address(alu_result),
    .reg_read(read_reg2),
    .f3(f3),
    .byte_enable(mem_byte_enable),
    .data(mem_write_data)
);


/**
* DATA CACHE
*/

wire [31:0] mem_read;
cache_state_t d_cache_state;

holy_data_cache data_cache (
    .clk(clk),
    .rst_n(rst_n),

    .aclk(m_axi.aclk),

    // CPU IF
    .address(alu_result),
    .write_data(mem_write_data),
    .read_enable(mem_read_enable),
    .write_enable(mem_write_enable),
    .byte_enable(mem_byte_enable),
    .read_data(mem_read),
    .cache_stall(d_cache_stall),

    // Incomming CSR orders
    .csr_flush_order(csr_flush_order),
    .non_cachable_base(csr_non_cachable_base),
    .non_cachable_limit(csr_non_cachable_limit),

    // M_AXI EXERNAL REQ IF
    .axi(m_axi_data),
    .axi_lite(m_axi_lite),
    .cache_state(d_cache_state),

    //debug
    .set_ptr_out(debug_d_set_ptr),
    .next_set_ptr_out(debug_d_next_set_ptr),
    .debug_seq_stall(debug_d_cache_seq_stall),
    .debug_comb_stall(debug_d_cache_comb_stall),
    .debug_next_cache_state(debug_d_cache_next_state)
);

/**
* READER
*/

wire [31:0] mem_read_write_back_data;
wire mem_read_write_back_valid;

assign debug_mem_read = mem_read;
assign debug_mem_byte_en = mem_byte_enable;
assign debug_wb_data = mem_read_write_back_data;

reader reader_inst(
    .mem_data(mem_read),
    .be_mask(mem_byte_enable),
    .f3(f3),
    .wb_data(mem_read_write_back_data),
    .valid(mem_read_write_back_valid)
);
    
endmodule