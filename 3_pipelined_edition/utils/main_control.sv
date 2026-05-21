import holy_core_pkg::*;


/*
 * HOLY CORE CONTROL UNIT
 *
 * BRH 10/24
 *
 * Generic control unit. Refer to the schematics.
 *
 * dev note 2025-08-04 (rur1k):
 * seperated the main control signals from specific control signals
 * to make room for optimizations when needed
 */

`timescale 1ns / 1ps

module main_control (
    // IN
    input logic [6:0] opcode,

    // OUT
    output logic mem_write,
    output logic reg_write,
    output logic alu_source,
    output logic [2:0] imm_source,
    output logic [1:0] alu_op,
    output logic r_type,
    output logic branch,
    output logic jump,
    output logic jalr,
    output logic lui,
    output logic auipc,
    output logic mem_to_reg
);

  alu_op_t alu_op_enum;
  opcode_t opcode_enum;
  assign opcode_enum = opcode_t'(opcode);

  always_comb begin

    mem_write = 1'b0;
    reg_write = 1'b0;
    alu_source = 1'b0;
    alu_op_enum = ALU_OP_LOAD_STORE;
    branch = 1'b0;
    jump = 1'b0;
    jalr = 1'b0;
    lui = 1'b0;
    auipc = 1'b0;
    mem_to_reg = 1'b0;
    r_type = 1'b0;
    imm_source = 3'b000;

    case (opcode_enum)
      OPCODE_R_TYPE: begin
        reg_write = 1'b1;
        alu_op_enum = ALU_OP_R_TYPE;
        r_type = 1'b1;
      end
      OPCODE_I_TYPE_ALU: begin
        imm_source  = 3'b000;
        reg_write   = 1'b1;
        alu_source  = 1'b1;
        alu_op_enum = ALU_OP_I_TYPE;
      end
      OPCODE_I_TYPE_LOAD: begin
        imm_source  = 3'b000;
        reg_write   = 1'b1;
        alu_source  = 1'b1;
        alu_op_enum = ALU_OP_LOAD_STORE;
        mem_to_reg  = 1'b1;
      end
      OPCODE_S_TYPE: begin
        imm_source  = 3'b001;
        mem_write   = 1'b1;
        alu_source  = 1'b1;
        alu_op_enum = ALU_OP_LOAD_STORE;
      end
      OPCODE_B_TYPE: begin
        imm_source = 3'b010;
        alu_op_enum = ALU_OP_BRANCHES;
        branch = 1'b1;
      end
      OPCODE_U_TYPE_LUI: begin
        imm_source = 3'b100;
        imm_source = 3'b100;
        reg_write = 1'b1;
        alu_source = 1'b0;
        alu_op_enum = ALU_OP_LOAD_STORE;
        lui = 1'b1;
      end
      OPCODE_U_TYPE_AUIPC: begin
        imm_source = 3'b100;
        reg_write = 1'b1;
        alu_source = 1'b1;
        alu_op_enum = ALU_OP_LOAD_STORE;
        auipc = 1'b1;
      end
      OPCODE_J_TYPE: begin
        imm_source = 3'b011;
        reg_write = 1'b1;
        alu_op_enum = ALU_OP_LOAD_STORE;
        jump = 1'b1;
      end
      OPCODE_J_TYPE_JALR: begin
        imm_source = 3'b000;
        reg_write = 1'b1;
        alu_op_enum = ALU_OP_LOAD_STORE;
        jump = 1'b1;
        jalr = 1'b1;
      end

    endcase
  end
  assign alu_op = alu_op_enum;

endmodule
