`timescale 1ns/1ps

module control (
    // IN
    input logic [6:0] op,
    input logic [2:0] func3,
    input logic [6:0] func7,
    input logic alu_zero,

    // OUT
    output logic [2:0] alu_control,
    output logic [2:0] imm_source,
    output logic mem_write,
    output logic reg_write,
    output logic alu_source,
    output logic [1:0] write_back_source,
    output logic pc_source,
    output logic second_add_source
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
            reg_write = 1'b1;
            imm_source = 3'b000;
            alu_source = 1'b1; //imm
            mem_write = 1'b0;
            alu_op = 2'b10;
            write_back_source = 2'b00; //alu_result
            branch = 1'b0;
            jump = 1'b0;
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
            second_add_source = 1'b0;
        end
        // J-type
        7'b1101111 : begin
            reg_write = 1'b1;
            imm_source = 3'b011;
            mem_write = 1'b0;
            write_back_source = 2'b10; //pc_+4
            branch = 1'b0;
            jump = 1'b1;
            second_add_source = 1'b0;
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
                1'b1 : second_add_source = 1'b1; // lui
                1'b0 : second_add_source = 1'b0; // auipc
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
        2'b00 : alu_control = 3'b000;
        // R-Types
        2'b10 : begin
            case (func3)
                // ADD (and later SUB with a different F7)
                3'b000 : alu_control = 3'b000;
                // AND
                3'b111 : alu_control = 3'b010;
                // OR
                3'b110 : alu_control = 3'b011;
                // SLTI
                3'b010 : alu_control = 3'b101;
                // SLTIU
                3'b011 : alu_control = 3'b111;
            endcase
        end
        // BEQ
        2'b01 : alu_control = 3'b001;
        // EVERYTHING ELSE
        default: alu_control = 3'b111;
    endcase
end

/**
* PC_Source
*/
assign pc_source = (alu_zero & branch) | jump;
    
endmodule