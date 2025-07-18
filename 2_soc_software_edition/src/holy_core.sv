/*
* HOLY CORE
*
* BRH 10/24
*
* Description: Holy_core cpu top module.
*              A simple core to solve simple problems. Thus the holyness ;)
*              This top module may need wrappers to be implemented in SoCs.
*              "Yea, though I walk through the valley of the shadow of death
*              I will fear no evil: for thou art with me;
*              thy rod and thy staff they comfort me."
*/

`timescale 1ns/1ps

module holy_core #(
    // IF DCACHE_EN is 0, we only enerate the non cache version.
    // Which is lighter, less complex and more suited to simple FPGA SoCs.
    parameter DCACHE_EN = 0
)(
    input logic clk,
    input logic rst_n,
    // AXI Interface for external requests
    axi_if.master m_axi,
    axi_lite_if.master m_axi_lite,

    // Interrupts
    input logic timer_itr,
    input logic soft_itr,
    input logic ext_itr,

    // DEBUG SIGNALS FOR LOGIC ANALYSERS
    output logic [31:0] debug_pc,  
    output logic [31:0] debug_pc_next,
    output logic [1:0] debug_pc_source,
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
assign debug_wb_data = mem_read_write_back_data;
assign debug_mem_read = mem_read;
assign debug_mem_byte_en = mem_byte_enable;
// Note : Cache ILA debug signals are at cache declaration

// others are assign directly to submodules outputs

/**
* M_AXI_ARBITRER, aka "mr l'arbitre"
*/

// note : AXI_LITE if is declared directly as output
axi_if m_axi_data();
axi_if m_axi_instr();

generate
    if (DCACHE_EN) begin : with_dcache
        external_req_arbitrer mr_l_arbitre(
            .m_axi(m_axi),
            .s_axi_instr(m_axi_instr),
            .i_cache_state(i_cache_state),
            .s_axi_data(m_axi_data),
            .d_cache_state(d_cache_state)
        );
    end else begin : no_dcache
        // Directly assign m_axi_instr to m_axi
        // manually because synthesis would not
        // be happy otherwise
        assign m_axi.awvalid = m_axi_instr.awvalid;
        assign m_axi.awaddr  = m_axi_instr.awaddr;
        assign m_axi.awid    = m_axi_instr.awid;
        assign m_axi.awlen   = m_axi_instr.awlen;
        assign m_axi.awsize  = m_axi_instr.awsize;
        assign m_axi.awburst = m_axi_instr.awburst;
        assign m_axi.awlock  = m_axi_instr.awlock;
        assign m_axi.awqos   = m_axi_instr.awqos;

        assign m_axi.wvalid  = m_axi_instr.wvalid;
        assign m_axi.wdata   = m_axi_instr.wdata;
        assign m_axi.wstrb   = m_axi_instr.wstrb;
        assign m_axi.wlast   = m_axi_instr.wlast;

        assign m_axi.bready  = m_axi_instr.bready;

        assign m_axi.arvalid = m_axi_instr.arvalid;
        assign m_axi.araddr  = m_axi_instr.araddr;
        assign m_axi.arid    = m_axi_instr.arid;
        assign m_axi.arlen   = m_axi_instr.arlen;
        assign m_axi.arsize  = m_axi_instr.arsize;
        assign m_axi.arburst = m_axi_instr.arburst;
        assign m_axi.arlock  = m_axi_instr.arlock;
        assign m_axi.arqos   = m_axi_instr.arqos;

        assign m_axi_instr.awready = m_axi.awready;
        assign m_axi_instr.wready  = m_axi.wready;
        assign m_axi_instr.bvalid  = m_axi.bvalid;
        assign m_axi_instr.bid     = m_axi.bid;
        assign m_axi_instr.bresp   = m_axi.bresp;

        assign m_axi_instr.arready = m_axi.arready;
        assign m_axi_instr.rvalid  = m_axi.rvalid;
        assign m_axi_instr.rdata   = m_axi.rdata;
        assign m_axi_instr.rresp   = m_axi.rresp;
        assign m_axi_instr.rlast   = m_axi.rlast;
        assign m_axi_instr.rid     = m_axi.rid;
        assign m_axi.rready = m_axi_instr.rready;
    end
endgenerate

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
    pc_plus_four = pc + 4;

    // STALL has PRIORITY over all PC selection, when it is high, next pc
    // Will stay the excat same !
    if(stall)begin
        pc_next = pc;
    end else begin
        case (pc_source)
            SOURCE_PC_PLUS_4 : pc_next = pc_plus_four;
            SOURCE_PC_SECOND_ADD : pc_next = pc_plus_second_add;
            SOURCE_PC_MTVEC : pc_next = csr_mtvec;
            SOURCE_PC_MEPC : pc_next = csr_mepc;
        endcase
    end
end

always_comb begin : second_add_select
    case (second_add_source)
        SECOND_ADDER_SOURCE_PC : pc_plus_second_add = pc + immediate;
        SECOND_ADDER_SOURCE_ZERO : pc_plus_second_add = immediate;
        SECOND_ADDER_SOURCE_RD: pc_plus_second_add = read_reg1 + immediate;
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
wire instr_cache_valid;
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
    .cache_valid(instr_cache_valid),

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
alu_control_t alu_control;
imm_source_t imm_source;
wire mem_write_enable;
wire mem_read_enable;
wire reg_write;
// trap (exception and return) related outs
logic m_ret;
logic exception;
logic [30:0] exception_cause;
// out muxes wires
alu_source_t alu_source;
wb_source_t write_back_source;
pc_source_t pc_source;
second_add_source_t second_add_source;
csr_wb_source_t csr_write_back_source;

control control_unit(
    .instr(instruction),
    .op(op),
    .func3(f3),
    .func7(f7),
    .alu_zero(alu_zero),
    .alu_last_bit(alu_last_bit),
    .instr_cache_valid(instr_cache_valid),

    // CONTROL OUT
    .alu_control(alu_control),
    .imm_source(imm_source),
    .mem_write(mem_write_enable),
    .mem_read(mem_read_enable),
    .reg_write(reg_write),
    .csr_write_back_source(csr_write_back_source),
    .alu_source(alu_source),
    .write_back_source(write_back_source),
    .pc_source(pc_source),
    .second_add_source(second_add_source),
    .csr_write_enable(csr_write_enable),

    // TRAP HANDLING INFOS IN
    // to handle traps, control and csr work toghter.
    // note : clk and rst used to keep track of
    //  pending traps when stalling.
    .clk(clk),
    .rst_n(rst_n),
    .trap(trap),
    .stall(stall),

    // TRAP INFOS OUT
    // these communicate informations on sync exceptions
    // and return to csr file.
    .m_ret(m_ret),
    .exception(exception),
    .exception_cause(exception_cause)
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
// wb_valid is just here to avoid writing by default...
logic wb_valid;

logic [31:0] write_back_data;
always_comb begin
    case (write_back_source)
        WB_SOURCE_ALU_RESULT: begin
            write_back_data = alu_result;
            wb_valid = 1'b1;
        end
        WB_SOURCE_MEM_READ: begin
            write_back_data = mem_read_write_back_data;
            wb_valid = mem_read_write_back_valid;
        end
        WB_SOURCE_PC_PLUS_FOUR: begin
            write_back_data = pc_plus_four;
            wb_valid = 1'b1;
        end
        WB_SOURCE_SECOND_ADD: begin
            write_back_data = pc_plus_second_add;
            wb_valid = 1'b1;
        end
        WB_SOURCE_CSR_READ: begin
            write_back_data = csr_read_data;
            wb_valid = 1'b1;
        end
        default begin
            write_back_data = 32'hFFFFFFFF;
            wb_valid = 1'b0; // only 0 by default on wrong wb source select
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
    .write_enable(reg_write && wb_valid && ~stall),
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
    case (csr_write_back_source)
        CSR_WB_SOURCE_RD : csr_write_back_data = read_reg1;
        CSR_WB_SOURCE_IMM : csr_write_back_data = immediate;
    endcase
end

logic [11:0] csr_address;
assign csr_address = instruction[31:20];
logic [31:0] csr_read_data;
logic csr_write_enable;

// Trap related signals
logic trap;
logic [31:0] csr_mtvec;
logic [31:0] csr_mepc;


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
    .current_core_pc(pc),

    // interrupts in
    .timer_itr(timer_itr),
    .soft_itr(soft_itr),
    .ext_itr(ext_itr),

    // infos from control
    .m_ret(m_ret),
    .exception(exception),
    .exception_cause(exception_cause),

    // out
    .read_data(csr_read_data),
    .flush_cache_flag(csr_flush_order),
    .non_cachable_base_addr(csr_non_cachable_base),
    .non_cachable_limit_addr(csr_non_cachable_limit),

    // trap request signal
    // This trap flag is high for 1 cycle and until
    // m_ret is asserted, the CSR will not be able to
    // recreate a trap request.
    // No handshake, this simple design assumes control will
    // register it and adapt pc_next accordignly
    .trap(trap),
    .csr_mtvec(csr_mtvec),
    .csr_mepc(csr_mepc)
);

/**
* ALU
*/
wire [31:0] alu_result;
logic [31:0] alu_src2;

always_comb begin
    case (alu_source)
        ALU_SOURCE_IMM: alu_src2 = immediate;
        ALU_SOURCE_RD: alu_src2 = read_reg2;
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

// IF DCACHE_EN is 0, we only enerate the non cache version.
// Which is lighter, less complex and more suited to simple FPGA SoCs.
generate
    if (DCACHE_EN) begin : gen_data_cache
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

            // CSR
            .csr_flush_order(csr_flush_order),
            .non_cachable_base(csr_non_cachable_base),
            .non_cachable_limit(csr_non_cachable_limit),

            // AXI
            .axi(m_axi_data),
            .axi_lite(m_axi_lite),
            .cache_state(d_cache_state),

            // Debug
            .set_ptr_out(debug_d_set_ptr),
            .next_set_ptr_out(debug_d_next_set_ptr),
            .debug_seq_stall(debug_d_cache_seq_stall),
            .debug_comb_stall(debug_d_cache_comb_stall),
            .debug_next_cache_state(debug_d_cache_next_state)
        );
    end else begin : gen_data_no_cache
        holy_data_no_cache data_no_cache (
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

            // AXI LITE only
            .axi_lite(m_axi_lite),
            .cache_state(d_cache_state),

            // Debug
            .debug_seq_stall(debug_d_cache_seq_stall),
            .debug_comb_stall(debug_d_cache_comb_stall),
            .debug_next_cache_state(debug_d_cache_next_state)
        );
    end
endgenerate

/**
* READER
*/

wire [31:0] mem_read_write_back_data;
wire mem_read_write_back_valid;

reader reader_inst(
    .mem_data(mem_read),
    .be_mask(mem_byte_enable),
    .f3(f3),
    .wb_data(mem_read_write_back_data),
    .valid(mem_read_write_back_valid)
);
    
endmodule