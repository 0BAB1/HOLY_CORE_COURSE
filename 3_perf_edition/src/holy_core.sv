/*
* HOLY CORE
*
* BRH 10/24
*
* Description: Holy_core cpu top module.
*              A simple core to solve simple problems. Thus the holyness ;)
*              This top module may need wrappers to be implemented in SoCs.
*
*              "Yea, though I walk through the valley of the shadow of death
*              I will fear no evil: for thou art with me;
*              thy rod and thy staff they comfort me."
*/

`timescale 1ns/1ps

import holy_core_pkg::*;

module holy_core #(
    // IF DCACHE_EN is 0, we only enerate the non cache version.
    // Which is lighter, less complex and more suited to simple FPGA SoCs.
    parameter DCACHE_EN = 1
)(
    // DEBUG Support implemented via execution based method.
    // Using pulp platform's debug module. When a debug request comes
    // in, the core jumps to this address (DEBUG ROM). which is basically
    // a loop. Default addresses are the one from pulp's docs with base =0
    // for the debugger.
    // They wre set to inputs for easier sim handling. but a real impl,
    // they shall be wired to a constant.
    input logic [31:0] debug_halt_addr,
    input logic [31:0] debug_exception_addr,

    input logic clk,
    input logic rst_n,
    // AXI Interface for external requests
    axi_if.master m_axi,
    axi_lite_if.master m_axi_lite,

    // Interrupts
    input logic timer_itr,
    input logic soft_itr,
    input logic ext_itr,
    // Debug req
    input logic debug_req,

    // RAW DEBUG SIGNALS FOR LOGIC ANALYSERS
    output logic [31:0] debug_pc,  
    output logic [31:0] debug_pc_next,
    output logic [1:0] debug_pc_source,
    output logic [31:0] debug_instruction,  
    output logic debug_i_cache_stall,  
    output logic debug_d_cache_stall
);

/**
* FPGA Debug_out signals
*/
assign debug_pc = pc;  
assign debug_pc_next = pc_next;  
assign debug_instruction = instruction;  
assign debug_i_cache_stall = i_cache_stall;  
assign debug_d_cache_stall  = d_cache_stall;

/**
* TOP AXI INTERFACES MUXING
*/

(* DONT_TOUCH = "true" *) axi_if axi_data();
(* DONT_TOUCH = "true" *) axi_if axi_instr();
(* DONT_TOUCH = "true" *) axi_lite_if axi_lite_data();
(* DONT_TOUCH = "true" *) axi_lite_if axi_lite_instr();

// AXI FULL MUXER / ARBITRER
// Only really useful if DCACHE is enabled.
// BUT putting this in a generate block WILL
// make the AXI interface unusable for some reason.
external_req_arbitrer mr_l_arbitre(
    .clk(clk),
    .rst_n(rst_n),
    .m_axi(m_axi),
    .s_axi_instr(axi_instr),
    .i_cache_state(i_cachable_state),
    .s_axi_data(axi_data),
    .d_cache_state(d_cachable_state)
);

// AXI LITE MUXER / ARBITRER
external_req_arbitrer_lite lite_mux(
    .clk(clk),
    .rst_n(rst_n),
    // out if (to externals)
    .m_axi_lite(m_axi_lite),

    // in ifs + infos on cache state for preemption
    .s_axi_lite_instr(axi_lite_instr),
    .i_cache_state(i_non_cachable_state),
    .s_axi_lite_data(axi_lite_data),
    .d_cache_state(d_non_cachable_state)
);

/**
* PROGRAM COUNTER 
*/

reg [31:0] pc;
logic [31:0] pc_next;
logic [31:0] pc_anticipated;
logic [31:0] second_add_result;
logic [31:0] pc_plus_four;

// Stall from caches
logic stall;
logic d_cache_stall;
logic i_cache_stall;
assign stall = d_cache_stall | i_cache_stall | alu_stall;

always_comb begin : pc_select
    pc_plus_four = pc + 4;

    // compute the PC we should have in a "normal", flow
    case (pc_source)
        SOURCE_PC_PLUS_4 :      pc_anticipated = pc_plus_four;
        SOURCE_PC_SECOND_ADD :  pc_anticipated = second_add_result;
        SOURCE_PC_MTVEC :       pc_anticipated = csr_mtvec;
        SOURCE_PC_MEPC :        pc_anticipated = csr_mepc;
        SOURCE_PC_DPC :         pc_anticipated = csr_dpc;
        default :               pc_anticipated = pc_plus_four;
    endcase

    if(stall) begin
        pc_next = pc;
    end else if(jump_to_debug) begin
        pc_next = debug_halt_addr;
    end else if(jump_to_debug_exception) begin
        pc_next = debug_exception_addr;
    end else begin
        pc_next = pc_anticipated;
    end
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
* Todo : pour cache/ uncached logic in a separate module.
*/

logic [31:0]    instruction, instr_cachable_rdata, instr_non_cachable_rdata;
logic           instr_cachable_read_valid, instr_non_cachable_read_valid;
cache_state_t   i_cachable_state, i_non_cachable_state;

logic instr_read_ack;
// if a mem read / write is ongoing, then we wait for it to complete, otherwise, ack all.
assign instr_read_ack = (mem_read_enable || mem_write_enable) ? data_req_complete : 1'b1;

// determine cachability of requested PC
logic instr_non_cachable;
assign instr_non_cachable = (pc >= instr_non_cachable_base) && 
                          (pc < instr_non_cachable_limit);

holy_instr_cache instr_cache (
    .clk(clk),
    .rst_n(rst_n),

    // CPU IF
    .address(pc),
    .read_data(instr_cachable_rdata),
    // handshake
    .req_valid(~instr_non_cachable),
    .req_ready(),
    .read_valid(instr_cachable_read_valid),
    .read_ack(instr_read_ack),

    // M_AXI EXERNAL REQ IF
    .axi(axi_instr),
    .cache_state(i_cachable_state)
);

holy_no_cache instr_no_cache (
    .clk(clk),
    .rst_n(rst_n),

    // CPU IF
    .address(pc),
    .read_data(instr_non_cachable_rdata),
    .write_data('0),
    .byte_enable('0),
    // handshake
    .req_valid(instr_non_cachable),
    .req_ready(),
    .req_write('0),
    .read_valid(instr_non_cachable_read_valid),
    .read_ack(instr_read_ack),
    // AXI Lite
    .axi_lite(axi_lite_instr),
    .cache_state(i_non_cachable_state)
);

// stall the core if instruction is not valid
assign i_cache_stall = instr_non_cachable ? ~instr_non_cachable_read_valid : ~instr_cachable_read_valid;
assign instruction = instr_non_cachable ? instr_non_cachable_rdata : instr_cachable_rdata;

// instrruction valid flag for control and CSR decision making
logic instruction_valid;
assign instruction_valid = instr_non_cachable ? instr_non_cachable_read_valid : instr_cachable_read_valid;

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
wire alu_req_valid;
// trap (exception and return) related outs
logic m_ret;
logic d_ret;
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
    .instr_cache_valid(instruction_valid),
    .alu_aligned_addr(alu_aligned_addr),
    .second_add_aligned_addr(second_add_aligned_addr),

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
    .alu_req_valid(alu_req_valid),

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
    .exception_cause(exception_cause),

    // DEBUG
    .jump_to_debug(jump_to_debug),
    .jump_to_debug_exception(jump_to_debug_exception),
    .d_ret(d_ret)
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
write_back_t write_back_signal;

always_comb begin
    case (write_back_source)
        WB_SOURCE_ALU_RESULT: begin
            write_back_signal.data = alu_result;
            write_back_signal.valid = 1'b1;
        end
        WB_SOURCE_MEM_READ: begin
            write_back_signal.data  = mem_read_write_back_data;
            write_back_signal.valid = mem_read_write_back_valid;
        end
        WB_SOURCE_PC_PLUS_FOUR: begin
            write_back_signal.data  = pc_plus_four;
            write_back_signal.valid = 1'b1;
        end
        WB_SOURCE_SECOND_ADD: begin
            write_back_signal.data  = second_add_result;
            write_back_signal.valid = 1'b1;
        end
        WB_SOURCE_CSR_READ: begin
            write_back_signal.data  = csr_read_data;
            write_back_signal.valid = 1'b1;
        end
        default begin
            write_back_signal.data = 32'hFFFFFFFF;
            write_back_signal.valid = 1'b0; // only 0 by default on wrong wb source select
        end
    endcase
end

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
    .write_enable(reg_write && write_back_signal.valid && ~stall),
    .write_data(write_back_signal.data),
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
target_addr exception_target_addr;
assign exception_target_addr.alu_addr = alu_result;
assign exception_target_addr.second_adder_addr = second_add_result;

// Debug signals
logic jump_to_debug;
logic jump_to_debug_exception;
logic [31:0] csr_dpc;

// csr orders
logic csr_flush_order;
logic [31:0] data_non_cachable_base;
logic [31:0] data_non_cachable_limit;
logic [31:0] instr_non_cachable_base;
logic [31:0] instr_non_cachable_limit;

/* verilator lint_off PINMISSING */
csr_file holy_csr_file(
    //in
    .clk(clk),
    .rst_n(rst_n),
    .stall(stall),
    .f3(f3),
    .write_data(csr_write_back_data),
    .write_enable(csr_write_enable),
    .address(csr_address),
    .current_core_pc(pc),
    .anticipated_core_pc(pc_anticipated),
    .current_core_fetch_instr(instruction),
    .instruction_valid(instruction_valid),

    // interrupts in
    .timer_itr(timer_itr),
    .soft_itr(soft_itr),
    .ext_itr(ext_itr),
    // Debug
    .debug_req(debug_req),
    .jump_to_debug(jump_to_debug),
    .jump_to_debug_exception(jump_to_debug_exception),

    // infos from control
    .m_ret(m_ret),
    .d_ret(d_ret),
    .exception(exception),
    .exception_cause(exception_cause),
    .exception_target_addr(exception_target_addr),

    // out
    .read_data(csr_read_data),
    .flush_cache_flag(csr_flush_order),
    .data_non_cachable_base_o(data_non_cachable_base),
    .data_non_cachable_limit_o(data_non_cachable_limit),
    .instr_non_cachable_base_o(instr_non_cachable_base),
    .instr_non_cachable_limit_o(instr_non_cachable_limit),

    // trap request signal
    // This trap flag is high for 1 cycle and until
    // m_ret is asserted, the CSR will not be able to
    // recreate a trap request.
    // No handshake, this simple design assumes control will
    // register it and adapt pc_next accordignly
    .trap(trap),
    .csr_mtvec(csr_mtvec),
    .csr_mepc(csr_mepc),

    // debug dpc for exiting debug mode
    .csr_dpc(csr_dpc)
);
/* verilator lint_on PINMISSING */

/**
* ALUs
*/

// sr2 MUX
logic [31:0] alu_src2;
always_comb begin
    case (alu_source)
        ALU_SOURCE_IMM: alu_src2 = immediate;
        ALU_SOURCE_RD: alu_src2 = read_reg2;
    endcase
end

wire [31:0] alu_base_result;
aligned_addr_signal alu_aligned_addr; // exception infos

alu alu_inst(
    .alu_control(alu_control),
    .src1(read_reg1),
    .src2(alu_src2),
    .alu_result(alu_base_result),
    .zero(alu_zero),
    .last_bit(alu_last_bit),
    .aligned_addr(alu_aligned_addr)
);

logic   alu_stall;
logic   mdu_res_valid;
logic   mdu_res_ack;
assign  mdu_res_ack = mdu_res_valid && ~i_cache_stall && ~d_cache_stall;

logic   is_mul_div;
assign  is_mul_div = alu_control >= ALU_MUL && alu_control != ALU_ERROR; // this assignment is NOT stable (todo)!!!

logic   mdu_req_valid;
assign  mdu_req_valid = alu_req_valid && is_mul_div && instruction_valid;

wire    [31:0] mdu_result;

mul_div_unit mdu(
    .clk,
    .rst_n,
    // Operands
    .src1(read_reg1),
    .src2(read_reg2),
    .mdu_control(alu_control),
    // Handshake
    .req_valid(mdu_req_valid),
    .res_ack(mdu_res_ack),
    .res_valid(mdu_res_valid),
    // Result
    .mdu_result(mdu_result)
);

assign  alu_stall = mdu_req_valid && !(mdu_res_valid && mdu_res_ack);

// alu/mdu result mux
logic   [31:0] alu_result;
assign  alu_result = is_mul_div ? mdu_result : alu_base_result;

/**
* SECOND ADDER
*/

aligned_addr_signal second_add_aligned_addr; // exception infos

// Scond add src MUX
always_comb begin : second_add_select
    case (second_add_source)
        SECOND_ADDER_SOURCE_PC : second_add_result = pc + immediate;
        SECOND_ADDER_SOURCE_ZERO : second_add_result = immediate;
        SECOND_ADDER_SOURCE_RD: second_add_result = read_reg1 + immediate;
        default : second_add_result = 32'd0;
    endcase

    // Address alignment flags
    second_add_aligned_addr.word_aligned     = (second_add_result[1:0] == 2'b00);
    second_add_aligned_addr.halfword_aligned = (second_add_result[0]   == 1'b0);
end

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
* DATA CACHE GENERATION
* Todo : pour cache/ uncached logic in a separate module.
*/

// We need to translate control's simple ENABLE signals into a well
// formulated handshake. Note that while I cache is stalling, we do
// not request to data IF.
logic data_req_valid;
logic data_req_write;
logic data_req_ready;
logic data_read_valid;
logic data_read_ack;
// request complete marker
logic data_req_complete;
assign data_req_complete = (data_read_valid && data_read_ack) || (data_req_valid && data_req_write && data_req_ready);

assign data_req_valid = ~i_cache_stall && (mem_write_enable || mem_read_enable);
assign data_req_write = mem_write_enable;
assign data_read_ack = 1'b1; // Always ack reads immediately

// Generate the stalling signal based on handshake state
always_comb begin
    d_cache_stall = 1;

    // Stall if we have a valid request but cache is not ready
    if(~data_req_valid) begin
        d_cache_stall = 1'b0;
    end else begin
        d_cache_stall = ~data_req_complete;
    end
end

wire    [31:0]  mem_read;
wire    [31:0]  cachable_mem_read, non_cachable_mem_read;
cache_state_t   d_cachable_state, d_non_cachable_state;
logic           non_cachable;
logic           cachable_req_valid, non_cachable_req_valid;
logic           cachable_req_ready, non_cachable_req_ready;
logic           cachable_read_valid, non_cachable_read_valid;

generate
if (DCACHE_EN) begin : gen_data_cache
    // We generate a dcache + a nocache for non cachable transactions.
    assign non_cachable = (alu_result >= data_non_cachable_base) && 
                          (alu_result < data_non_cachable_limit);
    
    // Route requests based on cachability
    assign cachable_req_valid = data_req_valid && ~non_cachable;
    assign non_cachable_req_valid = data_req_valid && non_cachable;
    
    // Mux ready and read_valid signals from active module
    assign data_req_ready = non_cachable ? non_cachable_req_ready : cachable_req_ready;
    assign data_read_valid = non_cachable ? non_cachable_read_valid : cachable_read_valid;
    
    holy_data_cache #(
        .WORDS_PER_LINE(32),
        .NUM_SETS(16)
    ) data_cache (
        .clk(clk),
        .rst_n(rst_n),
        .address(alu_result),
        .write_data(mem_write_data),
        .byte_enable(mem_byte_enable),
        // Handshake signals
        .req_valid(cachable_req_valid),
        .req_ready(cachable_req_ready),
        .req_write(data_req_write),
        .read_valid(cachable_read_valid),
        .read_ack(data_read_ack),
        .read_data(cachable_mem_read),
        // CSR
        .csr_flush_order(csr_flush_order),
        .axi(axi_data),
        .cache_state(d_cachable_state)
    );
    
    holy_no_cache data_no_cache (
        .clk(clk),
        .rst_n(rst_n),
        .address(alu_result),
        .write_data(mem_write_data),
        .byte_enable(mem_byte_enable),
        // Handshake signals
        .req_valid(non_cachable_req_valid),
        .req_ready(non_cachable_req_ready),
        .req_write(data_req_write),
        .read_valid(non_cachable_read_valid),
        .read_ack(data_read_ack),
        .read_data(non_cachable_mem_read),
        // AXI Lite
        .axi_lite(axi_lite_data),
        .cache_state(d_non_cachable_state)
    );
    
    // Mux outputs based on address range
    assign mem_read = non_cachable ? non_cachable_mem_read : cachable_mem_read;
    
end else begin : gen_data_no_cache
    
    assign non_cachable = 1'b0;
    
    // Direct assignment when no dcache
    assign non_cachable_req_valid = data_req_valid;
    assign data_req_ready = non_cachable_req_ready;
    assign data_read_valid = non_cachable_read_valid;
    
    holy_no_cache data_no_cache (
        .clk(clk),
        .rst_n(rst_n),
        .address(alu_result),
        .write_data(mem_write_data),
        .byte_enable(mem_byte_enable),
        // Handshake signals
        .req_valid(non_cachable_req_valid),
        .req_ready(non_cachable_req_ready),
        .req_write(data_req_write),
        .read_valid(non_cachable_read_valid),
        .read_ack(data_read_ack),
        .read_data(mem_read),
        // AXI Lite
        .axi_lite(axi_lite_data),
        .cache_state(d_non_cachable_state)
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