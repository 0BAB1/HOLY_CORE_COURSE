/** HOLY CORE PACKAGE
*
* This file contains a collection of signals values from RISC-V and core-specific specs.
*
* Author : BRH
*
* 12/24
*/

`timescale 1ns/1ps

package holy_core_pkg;

  typedef enum logic [3:0] { 
      IDLE, // Acts as simple BRAM array
      // AXI FULL STATES
      SENDING_WRITE_REQ,
      SENDING_WRITE_DATA,
      WAITING_WRITE_RES,
      SENDING_READ_REQ, // Data miss ! We have to fetch from memory ! State for as long as the req has not been acknowleged by memory slave
      RECEIVING_READ_DATA,  // Once REQ is acknowleged, we wait for full response. (tlast)
      // AXI LITE VERSIONS
      LITE_SENDING_WRITE_REQ,
      LITE_SENDING_WRITE_DATA,
      LITE_WAITING_WRITE_RES,
      LITE_SENDING_READ_REQ,
      LITE_RECEIVING_READ_DATA
  } cache_state_t;

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
    OPCODE_J_TYPE_JALR    = 7'b1100111,
    OPCODE_SYSTEM         = 7'b1110011
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
    ALU_SRA = 4'b1001,
    ALU_ERROR = 4'b1111 // to ditch once traps are implemented
  } alu_control_t;

  // IMM sources
  typedef enum logic [2:0] {
    I_IMM_SOURCE = 3'b000,
    S_IMM_SOURCE = 3'b001,
    B_IMM_SOURCE = 3'b010,
    J_IMM_SOURCE = 3'b011,
    U_IMM_SOURCE = 3'b100,
    CSR_IMM_SOURCE = 3'b101
  } imm_source_t;

  // WRITE BACK Sources
  typedef enum logic [2:0] {
    WB_SOURCE_ALU_RESULT = 3'b000,
    WB_SOURCE_MEM_READ = 3'b001,
    WB_SOURCE_PC_PLUS_FOUR = 3'b010,
    WB_SOURCE_SECOND_ADD = 3'b011,
    WB_SOURCE_CSR_READ = 3'b100
  } wb_source_t;

  // SECOND ADDER Sources (pc offsets operations)
  typedef enum logic [1:0] {
    SECOND_ADDER_SOURCE_PC = 2'b00,
    SECOND_ADDER_SOURCE_ZERO = 2'b01,
    SECOND_ADDER_SOURCE_RD = 2'b10
  } second_add_source_t;

  // CSR WRITE BACK SOURCE
  typedef enum logic {
    CSR_WB_SOURCE_RD = 1'b0,
    CSR_WB_SOURCE_IMM = 1'b1
  } csr_wb_source_t;

  // ALU SECOND ARG SOURCE
  typedef enum logic {
    ALU_SOURCE_RD = 1'b0,
    ALU_SOURCE_IMM = 1'b1
  } alu_source_t;

  // PC SOURCES
  typedef enum logic [1:0] {
    SOURCE_PC_PLUS_4 = 2'b00,
    SOURCE_PC_SECOND_ADD = 2'b01,
    SOURCE_PC_MTVEC = 2'b10,
    SOURCE_PC_MEPC = 2'b11
  } pc_source_t;

  // Write_back signal
  typedef struct packed {
    logic [31:0] data;
    logic valid;
  } write_back_t;

endpackage
