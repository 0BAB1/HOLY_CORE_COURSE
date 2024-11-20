`timescale 1ns/1ps

package holy_core_pkg;
  // https://docs.google.com/spreadsheets/d/1qkPa6muBsE1olzJDY9MTXeHVy1XvEswYHMTnvV1bRlU/edit?usp=sharing

  // INSTRUCTION OP CODES
  typedef enum logic [6:0] {
    OPCODE_R_TYPE         = 7'b0110011,
    OPCODE_I_TYPE_ALU     = 7'b0010011,
    OPCODE_I_TYPE_LOAD    = 7'b0000011,
    OPCODE_S_TYPE         = 7'b0100011,
    OPCODE_B_TYPE         = 7'b1100011,
    OPCODE_U_TYPE_LUI     = 7'b0110111,
    OPCODE_U_TYPE_AUIPC   = 7'b0010111,
    OPCODE_J_TYPE         = 7'b1101111,
    OPCODE_J_TYPE_JALR    = 7'b1100111
  } opcode_t;

  // ALU OPs for ALU DECODER
  typedef enum logic [1:0] {
    ALU_OP_LOAD_STORE     = 2'b00,
    ALU_OP_BRANCHES       = 2'b01,
    ALU_OP_MATH           = 2'b10
  } alu_op_t ;

  // "MATH" F3 (R&I Types)
  typedef enum logic [2:0] {
    F3_ADD_SUB = 3'b000,
    F3_SLL     = 3'b001,
    F3_SLT     = 3'b010,
    F3_SLTU    = 3'b011,
    F3_XOR     = 3'b100,
    F3_SRL_SRA = 3'b101,
    F3_OR      = 3'b110,
    F3_AND     = 3'b111
  } funct3_t;

  // BRANCHES F3
  typedef enum logic [2:0] {
    F3_BEQ  = 3'b000,
    F3_BNE  = 3'b001,
    F3_BLT  = 3'b100,
    F3_BGE  = 3'b101,
    F3_BLTU  = 3'b110,
    F3_BGEU  = 3'b111
  } branch_funct3_t;

  // LOAD & STORES F3
  typedef enum logic [2:0] {
    F3_WORD = 3'b010,
    F3_BYTE = 3'b000,
    F3_BYTE_U = 3'b100,
    F3_HALFWORD = 3'b001,
    F3_HALFWORD_U = 3'b101
  } load_store_funct3_t;

  // F7 for shifts
  typedef enum logic [6:0] {
    F7_SLL_SRL  = 7'b0000000,
    F7_SRA  = 7'b0100000
  } shifts_f7_t;

  // F7 for R-Types
  typedef enum logic [6:0] {
    F7_ADD  = 7'b0000000,
    F7_SUB  = 7'b0100000
  } rtype_f7_t;

  // ALU control arithmetic
  typedef enum logic [3:0] {
    ALU_ADD = 4'b0000,
    ALU_SUB = 4'b0001,
    ALU_AND = 4'b0010,
    ALU_OR = 4'b0011,
    ALU_SLL = 4'b0100,
    ALU_SLT = 4'b0101,
    ALU_SRL = 4'b0110,
    ALU_SLTU = 4'b0111,
    ALU_XOR = 4'b1000,
    ALU_SRA = 4'b1001
  } alu_control_t;

  // Write_back signal
  typedef struct packed {
    logic [31:0] data;
    logic valid;
  } write_back_t;

endpackage
