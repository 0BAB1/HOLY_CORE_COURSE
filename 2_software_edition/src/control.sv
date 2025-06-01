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
    input logic [6:0] op,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic alu_zero,
    input logic alu_last_bit,

    // OUT
    output logic [3:0] alu_control,
    output logic [2:0] imm_source,
    output logic mem_write,
    output logic mem_read,
    output logic reg_write,
    output logic alu_source,
    output logic [2:0] write_back_source,
    output logic pc_source,
    output logic [1:0] second_add_source,
    output logic csr_write_back_source,
    output logic csr_write_enable
);

import holy_core_pkg::*;
logic illegal_instr;

/**
* MAIN DECODER
*/

logic [1:0] alu_op;
logic branch;
logic jump;

always_comb begin
    // defaults
    imm_source = 3'b000;
    mem_write = 1'b0;
    mem_read = 1'b0;
    reg_write = 1'b0;
    alu_source = 1'b0;
    write_back_source = 3'b000;
    second_add_source = 2'b00;
    csr_write_back_source = 1'b0;
    csr_write_enable = 1'b0;
    illegal_instr = 1'b0;

    case (op)
        // I-type
        OPCODE_I_TYPE_LOAD : begin
            reg_write = 1'b1;
            imm_source = 3'b000;
            mem_write = 1'b0;
            mem_read = 1'b1;
            alu_op = 2'b00;
            alu_source = 1'b1; //imm
            write_back_source = 3'b001; //memory_read
            branch = 1'b0;
            jump = 1'b0;
            csr_write_enable = 1'b0;
        end
        // ALU I-type
        OPCODE_I_TYPE_ALU : begin
            imm_source = 3'b000;
            alu_source = 1'b1; //imm
            mem_write = 1'b0;
            alu_op = 2'b10;
            write_back_source = 3'b000; //alu_result
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
            imm_source = 3'b001;
            mem_read = 1'b0;
            mem_write = 1'b1;
            alu_op = 2'b00;
            alu_source = 1'b1; //imm
            branch = 1'b0;
            jump = 1'b0;
            csr_write_enable = 1'b0;
        end
        // R-Type
        OPCODE_R_TYPE : begin
            reg_write = 1'b1;
            mem_write = 1'b0;
            mem_read = 1'b0;
            alu_op = 2'b10;
            alu_source = 1'b0; //reg2
            write_back_source = 3'b000; //alu_result
            branch = 1'b0;
            jump = 1'b0;
            csr_write_enable = 1'b0;
        end
        // B-type
        OPCODE_B_TYPE : begin
            reg_write = 1'b0;
            imm_source = 3'b010;
            mem_read = 1'b0;
            alu_source = 1'b0;
            mem_write = 1'b0;
            alu_op = 2'b01;
            branch = 1'b1;
            jump = 1'b0;
            second_add_source = 2'b00;
            csr_write_enable = 1'b0;
        end
        // J-type + JALR weird Hybrib
        OPCODE_J_TYPE, OPCODE_J_TYPE_JALR : begin
            reg_write = 1'b1;
            imm_source = 3'b011;
            mem_read = 1'b0;
            mem_write = 1'b0;
            write_back_source = 3'b010; //pc_+4
            branch = 1'b0;
            jump = 1'b1;
            if(op[3]) begin// jal
                second_add_source = 2'b00;
                imm_source = 3'b011;
            end
            else if (~op[3]) begin // jalr
                second_add_source = 2'b10;
                imm_source = 3'b000;
            end
            csr_write_enable = 1'b0;
        end
        // U-type
        OPCODE_U_TYPE_LUI, OPCODE_U_TYPE_AUIPC : begin
            imm_source = 3'b100;
            mem_write = 1'b0;
            mem_read = 1'b0;
            reg_write = 1'b1;
            write_back_source = 3'b011;
            branch = 1'b0;
            jump = 1'b0;
            case(op[5])
                1'b1 : second_add_source = 2'b01; // lui
                1'b0 : second_add_source = 2'b00; // auipc
            endcase
            csr_write_enable = 1'b0;
        end
        // CSR instructions (SYSTEM OPCODE)
        OPCODE_CSR : begin
            imm_source = 3'b101;
            mem_write = 1'b0;
            reg_write = 1'b1;
            jump = 1'b0;
            write_back_source = 3'b100;
            // Determine wb src from MSB of F3
            // 3'b0xx is for rs value
            // 3'b1xx is for imm extended value
            csr_write_back_source = func3[2];
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
            $display("CONTROL: Unknown/Unsupported OP CODE : %b", op);
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
                    if(op == 7'b0110011) begin // R-type
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
                F3_BEQ, F3_BNE : alu_control = 4'b0001;
                // BLT, BGE
                F3_BLT, F3_BGE : alu_control = 4'b0101;
                // BLTU, BGEU
                F3_BLTU, F3_BGEU : alu_control = 4'b0111;
                default : alu_control = 4'b1111;
            endcase
        end
        default : alu_control = 4'b1111;
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