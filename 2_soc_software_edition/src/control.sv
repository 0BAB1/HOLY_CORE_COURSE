/*
* HOLY CORE CONTROL UNIT
*
* BRH 10/24
*
* Generic control unit. Refer to the schematics.
*/

`timescale 1ns/1ps

module control (
    // IN
    input opcode_t op,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic alu_zero,
    input logic alu_last_bit,

    // OUT
    output alu_control_t alu_control,
    output imm_source_t imm_source,
    output logic mem_write,
    output logic mem_read,
    output logic reg_write,
    output alu_source_t alu_source,
    output wb_source_t write_back_source,
    output logic pc_source,
    output second_add_source_t second_add_source,
    output csr_wb_source_t csr_write_back_source,
    output logic csr_write_enable
);

import holy_core_pkg::*;
logic illegal_instr;

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
    illegal_instr = 1'b0;

    case (op)
        // I-type
        OPCODE_I_TYPE_LOAD : begin
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
        // ALU I-type
        OPCODE_I_TYPE_ALU : begin
            imm_source = I_IMM_SOURCE;
            alu_source = ALU_SOURCE_IMM; //imm
            mem_write = 1'b0;
            alu_op = ALU_OP_MATH;
            write_back_source = WB_SOURCE_ALU_RESULT; //alu_result
            mem_read = 1'b0;
            branch = 1'b0;
            jump = 1'b0;
            // If we have a shift with a constant to handle, we have to invalidate writes for
            // instructions that does not have a well-formated immediate with "f7" and a 5bits shamt
            // ie :
            // - 7 upper bits are interpreted as a "f7", ony valid for a restricted slection tested below
            // - 5 lower as shamt (because max shift is 32bits and 2^5 = 32).
            if (func3 == F3_SLL) begin
                // Only slli valid with func7 = F7_SLL_SRL
                reg_write = (func7 == F7_SLL_SRL);
            end
            else if (func3 == F3_SRL_SRA) begin
                // srli: f7 = F7_SLL_SRL, srai: f7 = F7_SRA
                reg_write = (func7 == F7_SLL_SRL) || (func7 == F7_SRA);
            end
            else begin
                reg_write = 1'b1;
            end
            csr_write_enable = 1'b0;
        end
        // S-Type
        OPCODE_S_TYPE : begin
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
        // R-Type
        OPCODE_R_TYPE : begin
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
        // B-type
        OPCODE_B_TYPE : begin
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
        // J-type + JALR weird Hybrib
        OPCODE_J_TYPE, OPCODE_J_TYPE_JALR : begin
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
        // CSR instructions (SYSTEM OPCODE)
        OPCODE_CSR : begin
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
        // EVERYTHING ELSE
        default: begin
            // Don't touch the CPU nor MEMORY state, including CSR
            reg_write = 1'b0;
            mem_write = 1'b0;
            mem_read = 1'b0;
            jump = 1'b0;
            branch = 1'b0;
            csr_write_enable = 1'b0;
            illegal_instr = 1'b1;
            $display("CONTROL: Unknown/Unsupported OP CODE : %b", op); // todo : TRAP ILLEGAL
        end
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

/**
* PC_Source
*/

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

always_comb begin
    pc_source = 1'b0;
    if (op == OPCODE_B_TYPE && assert_branch) begin
        pc_source = 1'b1;
    end
    else if (jump) begin
        pc_source = 1'b1;
    end
end
    
endmodule