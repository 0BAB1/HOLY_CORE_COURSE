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
    output logic reg_write,
    output logic alu_source,
    output logic [1:0] write_back_source,
    output logic pc_source,
    output logic [1:0] second_add_source
);

/**
* MAIN DECODER
*/

logic [1:0] alu_op;
logic branch;
logic jump;

always_comb begin
    case (op)
        // I-type
        7'b0000011 : begin
            reg_write = 1'b1;
            imm_source = 3'b000;
            mem_write = 1'b0;
            alu_op = 2'b00;
            alu_source = 1'b1; //imm
            write_back_source =2'b01; //memory_read
            branch = 1'b0;
            jump = 1'b0;
        end
        // ALU I-type
        7'b0010011 : begin
            imm_source = 3'b000;
            alu_source = 1'b1; //imm
            mem_write = 1'b0;
            alu_op = 2'b10;
            write_back_source = 2'b00; //alu_result
            branch = 1'b0;
            jump = 1'b0;
            // If we have a shift with a contant to handle, we have to invalidate writes for
            // instructions that does not have a well-formated immediate with "f7" and a 5bits shamt
            // ie :
            // - 7 upper bits are interpreted as a "f7", ony valid for a restricted slection tested below
            // - 5 lower as shamt (because max shift is 32bits and 2^5 = 32).
            if(func3 == 3'b001)begin
                // slli only accept f7 7'b0000000
                reg_write = (func7 == 7'b0000000) ? 1'b1 : 1'b0;
            end
            else if(func3 == 3'b101)begin
                // srli only accept f7 7'b0000000
                // srli only accept f7 7'b0100000
                reg_write = (func7 == 7'b0000000 | func7 == 7'b0100000) ? 1'b1 : 1'b0;
            end else begin
                reg_write = 1'b1;
            end
        end
        // S-Type
        7'b0100011 : begin
            reg_write = 1'b0;
            imm_source = 3'b001;
            mem_write = 1'b1;
            alu_op = 2'b00;
            alu_source = 1'b1; //imm
            branch = 1'b0;
            jump = 1'b0;
        end
        // R-Type
        7'b0110011 : begin
            reg_write = 1'b1;
            mem_write = 1'b0;
            alu_op = 2'b10;
            alu_source = 1'b0; //reg2
            write_back_source = 2'b00; //alu_result
            branch = 1'b0;
            jump = 1'b0;
        end
        // B-type
        7'b1100011 : begin
            reg_write = 1'b0;
            imm_source = 3'b010;
            alu_source = 1'b0;
            mem_write = 1'b0;
            alu_op = 2'b01;
            branch = 1'b1;
            jump = 1'b0;
            second_add_source = 2'b00;
        end
        // J-type + JALR weird Hybrib
        7'b1101111, 7'b1100111 : begin
            reg_write = 1'b1;
            imm_source = 3'b011;
            mem_write = 1'b0;
            write_back_source = 2'b10; //pc_+4
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
        end
        // U-type
        7'b0110111, 7'b0010111 : begin
            imm_source = 3'b100;
            mem_write = 1'b0;
            reg_write = 1'b1;
            write_back_source = 2'b11;
            branch = 1'b0;
            jump = 1'b0;
            case(op[5])
                1'b1 : second_add_source = 2'b01; // lui
                1'b0 : second_add_source = 2'b00; // auipc
            endcase
        end
        // EVERYTHING ELSE
        default: begin
            // Don't touch the CPU nor MEMORY state
            reg_write = 1'b0;
            mem_write = 1'b0;
            jump = 1'b0;
            branch = 1'b0;
        end
    endcase
end

/**
* ALU DECODER
*/

always_comb begin
    case (alu_op)
        // LW, SW
        2'b00 : alu_control = 4'b0000;
        // R-Types, I-types
        2'b10 : begin
            case (func3)
                // ADD (and later SUB with a different F7)
                3'b000 : begin
                    // 2 scenarios here :
                    // - R-TYPE : either add or sub and we need to a check for that
                    // - I-Type : aadi -> we use add arithmetic
                    if(op == 7'b0110011) begin // R-type
                        alu_control = func7[5] ? 4'b0001 : 4'b0000;
                    end else begin // I-Type
                        alu_control = 4'b0000;
                    end
                end
                // AND
                3'b111 : alu_control = 4'b0010;
                // OR
                3'b110 : alu_control = 4'b0011;
                // SLTI
                3'b010 : alu_control = 4'b0101;
                // SLTIU
                3'b011 : alu_control = 4'b0111;
                // XOR
                3'b100 : alu_control = 4'b1000;
                // SLL
                3'b001 : alu_control = 4'b0100;
                // SRL, SRA
                3'b101 : begin
                    if(func7 == 7'b0000000) begin
                        alu_control = 4'b0110; // srl
                    end else if (func7 == 7'b0100000) begin
                        alu_control = 4'b1001; // sra
                    end
                end
            endcase
        end
        // BRANCHES
        2'b01 : begin
            case (func3)
                // BEQ, BNE
                3'b000, 3'b001 : alu_control = 4'b0001;
                // BLT, BGE
                3'b100, 3'b101 : alu_control = 4'b0101;
                // BLTU, BGEU
                3'b110, 3'b111 : alu_control = 4'b0111;
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
        3'b000 : assert_branch = alu_zero & branch;
        // BLT, BLTU
        3'b100, 3'b110 : assert_branch = alu_last_bit & branch;
        // BNE
        3'b001 : assert_branch = ~alu_zero & branch;
        // BGE, BGEU
        3'b101, 3'b111 : assert_branch = ~alu_last_bit & branch;
        default : assert_branch = 1'b0;
    endcase
end

assign pc_source = assert_branch | jump;
    
endmodule