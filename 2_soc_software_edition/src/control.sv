/*
* HOLY CORE CONTROL UNIT
*
* BRH 10/24
*
* Generic control unit. Refer to the schematics or pkg file.
*/

`timescale 1ns/1ps

import holy_core_pkg::*;

module control (
    // INSTRUCTION INFOS IN
    input logic [31:0] instr,
    input opcode_t op,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic alu_zero,
    input logic alu_last_bit,

    // CONTROL OUT
    output alu_control_t alu_control,
    output imm_source_t imm_source,
    output logic mem_write,
    output logic mem_read,
    output logic reg_write,
    output alu_source_t alu_source,
    output wb_source_t write_back_source,
    output pc_source_t pc_source,
    output second_add_source_t second_add_source,
    output csr_wb_source_t csr_write_back_source,
    output logic csr_write_enable,

    // TRAP HANDLING INFOS IN
    input logic clk,
    input logic rst_n,
    input logic trap,
    input logic stall,

    // TRAP INFOS OUT
    output logic m_ret,
    output logic exception,
    output logic [30:0] exception_cause
);

logic trap_pending;

/**
* MAIN DECODER
*/

alu_op_t alu_op;
logic branch;
logic jump;

always_comb begin
    // defaults
    imm_source = I_IMM_SOURCE;
    mem_write = 1'b0;
    mem_read = 1'b0;
    reg_write = 1'b0;
    alu_source = ALU_SOURCE_RD;
    write_back_source = WB_SOURCE_ALU_RESULT;
    second_add_source = SECOND_ADDER_SOURCE_PC;
    csr_write_back_source = CSR_WB_SOURCE_IMM;
    csr_write_enable = 1'b0;

    exception = 1;
    exception_cause = 31'd2;

    case (op)
        // I-type
        OPCODE_I_TYPE_LOAD : begin
            if(valid_load_func3)begin
                exception = 0;
                reg_write = 1'b1;
                imm_source = I_IMM_SOURCE;
                mem_write = 1'b0;
                mem_read = 1'b1;
                alu_op = ALU_OP_LOAD_STORE;
                alu_source = ALU_SOURCE_IMM;
                write_back_source = WB_SOURCE_MEM_READ;
                branch = 1'b0;
                jump = 1'b0;
                csr_write_enable = 1'b0;
            end
        end
        // ALU I-type
        OPCODE_I_TYPE_ALU : begin
            if(valid_alu_func3) begin
                exception = 0;
                imm_source = I_IMM_SOURCE;
                alu_source = ALU_SOURCE_IMM; //imm
                mem_write = 1'b0;
                alu_op = ALU_OP_MATH;
                write_back_source = WB_SOURCE_ALU_RESULT; //alu_result
                mem_read = 1'b0;
                branch = 1'b0;
                jump = 1'b0;
                reg_write = 1'b1;
                csr_write_enable = 1'b0;
            end
        end
        // S-Type
        OPCODE_S_TYPE : begin
            if(valid_store_func3) begin
                exception = 0;
                reg_write = 1'b0;
                imm_source = S_IMM_SOURCE;
                mem_read = 1'b0;
                mem_write = 1'b1;
                alu_op = ALU_OP_LOAD_STORE;
                alu_source = ALU_SOURCE_IMM;
                branch = 1'b0;
                jump = 1'b0;
                csr_write_enable = 1'b0;
            end
        end
        // R-Type
        OPCODE_R_TYPE : begin
            if(valid_rtype_combination) begin
                exception = 0;
                reg_write = 1'b1;
                mem_write = 1'b0;
                mem_read = 1'b0;
                alu_op = ALU_OP_MATH;
                alu_source = ALU_SOURCE_RD;
                write_back_source = WB_SOURCE_ALU_RESULT;
                branch = 1'b0;
                jump = 1'b0;
                csr_write_enable = 1'b0;
            end
        end
        // B-type
        OPCODE_B_TYPE : begin
            if(valid_branch_func3) begin
                exception = 0;
                reg_write = 1'b0;
                imm_source = B_IMM_SOURCE;
                mem_read = 1'b0;
                alu_source = ALU_SOURCE_RD;
                mem_write = 1'b0;
                alu_op = ALU_OP_BRANCHES;
                branch = 1'b1;
                jump = 1'b0;
                second_add_source = SECOND_ADDER_SOURCE_PC;
                csr_write_enable = 1'b0;
            end
        end
        // J-type + JALR weird Hybrib
        OPCODE_J_TYPE, OPCODE_J_TYPE_JALR : begin
            exception = 0;
            reg_write = 1'b1;
            imm_source = J_IMM_SOURCE;
            mem_read = 1'b0;
            mem_write = 1'b0;
            write_back_source = WB_SOURCE_PC_PLUS_FOUR;
            branch = 1'b0;
            jump = 1'b1;
            if(op[3]) begin// jal
                second_add_source = SECOND_ADDER_SOURCE_PC;
                imm_source = J_IMM_SOURCE;
            end
            else if (~op[3]) begin // jalr
                second_add_source = SECOND_ADDER_SOURCE_RD;
                imm_source = I_IMM_SOURCE;
            end
            csr_write_enable = 1'b0;
        end
        // U-type
        OPCODE_U_TYPE_LUI, OPCODE_U_TYPE_AUIPC : begin
            exception = 0;
            imm_source = U_IMM_SOURCE;
            mem_write = 1'b0;
            mem_read = 1'b0;
            reg_write = 1'b1;
            write_back_source = WB_SOURCE_SECOND_ADD;
            branch = 1'b0;
            jump = 1'b0;
            case(op[5])
                1'b1 : second_add_source = SECOND_ADDER_SOURCE_ZERO; // lui
                1'b0 : second_add_source = SECOND_ADDER_SOURCE_PC; // auipc
            endcase
            csr_write_enable = 1'b0;
        end
        // SYSTEM OPCODE
        OPCODE_SYSTEM : begin
            case (func3)
                // === ECALL & EBREAK ===
                3'b000: begin
                    exception = 0;
                    // Check immediate field to know if ECALL or EBREAK
                    if (instr[31:20] == 12'b0000_0000_0000) begin
                        // ECALL
                        exception = 1'b1;
                        exception_cause = 31'd11;
                    end
                    else if (instr[31:20] == 12'b0000_0000_0001) begin
                        // EBREAK
                        exception = 1'b1;
                        exception_cause = 31'd3;
                    end
                    else if (instr[31:20] == 12'b0011_0000_0010) begin
                        // MRET
                        m_ret = 1'b1;
                    end
                end
                // === CSR instructions ===
                3'b001, 3'b010, 3'b011,
                3'b101, 3'b110, 3'b111: begin
                    exception = 0;
                    imm_source = CSR_IMM_SOURCE;
                    mem_write = 1'b0;
                    reg_write = 1'b1;
                    jump = 1'b0;
                    write_back_source = WB_SOURCE_CSR_READ;
                    // Determine wb src from MSB of F3CSR_WB_SOURCE_IMM
                    // 3'b0xx is for rs value
                    // 3'b1xx is for imm extended value
                    if(func3[2])    csr_write_back_source = CSR_WB_SOURCE_IMM;
                    if(~func3[2])   csr_write_back_source = CSR_WB_SOURCE_RD;
                    csr_write_enable = 1'b1;
                end
                default:;
            endcase
        end
        default:;
    endcase
end

/**
* ALU DECODER
*/

always_comb begin
    case (alu_op)
        // LW, SW
        ALU_OP_LOAD_STORE : alu_control = ALU_ADD;
        // R-Types, I-types
        ALU_OP_MATH : begin
            case (func3)
                // ADD (and later SUB with a different F7)
                F3_ADD_SUB : begin
                    // 2 scenarios here :
                    // - R-TYPE : either add or sub and we need to a check for that
                    // - I-Type : aadi -> we use add arithmetic
                    if(op == OPCODE_R_TYPE) begin // R-type
                        alu_control = (func7 == F7_SUB)? ALU_SUB : ALU_ADD;
                    end else begin // I-Type
                        alu_control = ALU_ADD;
                    end
                end
                // AND
                F3_AND : alu_control = ALU_AND;
                // OR
                F3_OR : alu_control = ALU_OR;
                // SLT, SLTI
                F3_SLT: alu_control = ALU_SLT;
                // SLTU, SLTIU
                F3_SLTU : alu_control = ALU_SLTU;
                // XOR
                F3_XOR : alu_control = ALU_XOR;
                // SLL
                F3_SLL : alu_control = ALU_SLL;
                // SRL, SRA
                F3_SRL_SRA : begin
                    if(func7 == F7_SLL_SRL) begin
                        alu_control = ALU_SRL; // srl
                    end else if (func7 == F7_SRA) begin
                        alu_control = ALU_SRA; // sra
                    end
                end
            endcase
        end
        // BRANCHES
        ALU_OP_BRANCHES : begin
            case (func3)
                // BEQ, BNE
                F3_BEQ, F3_BNE : alu_control = ALU_SUB;
                // BLT, BGE
                F3_BLT, F3_BGE : alu_control = ALU_SLT;
                // BLTU, BGEU
                F3_BLTU, F3_BGEU : alu_control = ALU_SLTU;
                default : alu_control = ALU_ERROR; // undefinied, todo : TRAP ILLEGAL
            endcase
        end
        default : alu_control = ALU_ERROR; // undefinied, todo : TRAP ILLEGAL
    endcase
end

logic assert_branch;

always_comb begin : branch_logic_decode
    case (func3)
        // BEQ
        F3_BEQ : assert_branch = alu_zero & branch;
        // BLT, BLTU
        F3_BLT, F3_BLTU : assert_branch = alu_last_bit & branch;
        // BNE
        F3_BNE : assert_branch = ~alu_zero & branch;
        // BGE, BGEU
        F3_BGE, F3_BGEU : assert_branch = ~alu_last_bit & branch;
        default : assert_branch = 1'b0;
    endcase
end

/**
* PC_Source
*/

always_comb begin : pc_source_select
    pc_source = SOURCE_PC_PLUS_4;
    if (trap || trap_pending) begin
        pc_source = SOURCE_PC_MTVEC;
    end
    else if (op == OPCODE_B_TYPE && assert_branch) begin
        pc_source = SOURCE_PC_SECOND_ADD;
    end
    else if (jump) begin
        pc_source = SOURCE_PC_SECOND_ADD;
    end
end

/**
* TRAP RELATED LOGIC
*/

// NOTE: trap flag is high for only 1 cycle when a request is recieved.
// Because we can stall at any given time, we use trap_pending.
//
// Trap is considered *taken* when the global stall goes low,
// because the entire core (including PC update) is stalled.
// This is safe because our core is simple and fully synchronous.
// This may be a concern for more complex pipelined designs.

always_ff @( posedge clk ) begin : trap_latch
    if(~rst_n) begin
        trap_pending <= 1'b0;
    end else begin
        trap_pending <= trap_pending;

        if(~trap_pending && trap && stall) begin
            // keep track of trap, request if stalling
            trap_pending <= 1'b1;
        end
        
        if (trap_pending && ~stall) begin
            trap_pending <= 1'b0;
        end
    end
end

/**
* DEFINE "VALID" WIRES
*/

// TODO : declare all in pkg. But fuck that for now...
    
// === VALID FUNC3 / FUNC7 for RV32I ===

// Loads (LB, LH, LW, LBU, LHU)
wire valid_load_func3 = (func3 == 3'b000) || // LB
                        (func3 == 3'b001) || // LH
                        (func3 == 3'b010) || // LW
                        (func3 == 3'b100) || // LBU
                        (func3 == 3'b101);   // LHU

// Stores (SB, SH, SW)
wire valid_store_func3 = (func3 == 3'b000) || // SB
                         (func3 == 3'b001) || // SH
                         (func3 == 3'b010);   // SW

// ALU I-type ops (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
wire valid_alu_func3 = (func3 == 3'b000) || // ADDI
                       (func3 == 3'b001) || // SLLI (shift left logical immediate)
                       (func3 == 3'b010) || // SLTI
                       (func3 == 3'b011) || // SLTIU
                       (func3 == 3'b100) || // XORI
                       (func3 == 3'b101) || // SRLI and SRAI (distinguished by func7)
                       (func3 == 3'b110) || // ORI
                       (func3 == 3'b111);   // ANDI

// Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
wire valid_branch_func3 = (func3 == 3'b000) || // BEQ
                          (func3 == 3'b001) || // BNE
                          (func3 == 3'b100) || // BLT
                          (func3 == 3'b101) || // BGE
                          (func3 == 3'b110) || // BLTU
                          (func3 == 3'b111);   // BGEU

// R-type ALU ops (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
wire valid_rtype_combination = (
    // ADD, SUB
    (func3 == 3'b000 && (func7 == 7'b0000000 || func7 == 7'b0100000)) ||
    // SLL
    (func3 == 3'b001 && func7 == 7'b0000000) ||
    // SLT
    (func3 == 3'b010 && func7 == 7'b0000000) ||
    // SLTU
    (func3 == 3'b011 && func7 == 7'b0000000) ||
    // XOR
    (func3 == 3'b100 && func7 == 7'b0000000) ||
    // SRL, SRA
    (func3 == 3'b101 && (func7 == 7'b0000000 || func7 == 7'b0100000)) ||
    // OR
    (func3 == 3'b110 && func7 == 7'b0000000) ||
    // AND
    (func3 == 3'b111 && func7 == 7'b0000000)
);


endmodule