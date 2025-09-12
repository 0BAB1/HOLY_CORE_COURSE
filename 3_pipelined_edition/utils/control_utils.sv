import holy_core_pkg::*;

/*
 * alu controller
 *
 * rur1k 2025-08-04
 *
 * dev note 2025-08-04 (rur1k):
 * logic seperation will beneficial for the project maintainability and logic
 * expansion in the future
 */

module alu_control (
    input  [1:0] alu_op,
    input  [2:0] func3,
    input  [6:0] func7,
    output [3:0] alu_ctrl
);

  alu_op_t alu_op_enum;
  alu_control_t alu_ctrl_enum;
  assign alu_op_enum = alu_op_t'(alu_op);
  funct3_t func3_alu_enum;
  assign func3_alu_enum = funct3_t'(func3);
  branch_funct3_t func3_branch_enum;
  assign func3_branch_enum = branch_funct3_t'(func3);

  always @(*) begin
    alu_ctrl_enum = ALU_ADD;
    case (alu_op_enum)
      ALU_OP_LOAD_STORE: begin
        alu_ctrl_enum = ALU_ADD;
      end
      ALU_OP_R_TYPE: begin
        case (func3_alu_enum)
          F3_ADD_SUB: begin
            if (func7[5]) alu_ctrl_enum = ALU_SUB;
            else alu_ctrl_enum = ALU_ADD;
          end
          F3_SLL:  alu_ctrl_enum = ALU_SLL;
          F3_SLT:  alu_ctrl_enum = ALU_SLT;
          F3_SLTU: alu_ctrl_enum = ALU_SLTU;
          F3_XOR:  alu_ctrl_enum = ALU_XOR;
          F3_SRL_SRA: begin
            if (func7[5]) alu_ctrl_enum = ALU_SRA;
            else alu_ctrl_enum = ALU_SRL;
          end
          F3_OR:   alu_ctrl_enum = ALU_OR;
          F3_AND:  alu_ctrl_enum = ALU_AND;
          default: ;
        endcase
      end
      ALU_OP_I_TYPE: begin
        case (func3_alu_enum)
          F3_ADD_SUB: alu_ctrl_enum = ALU_ADD;
          F3_SLL: alu_ctrl_enum = ALU_SLL;
          F3_SLT: alu_ctrl_enum = ALU_SLT;
          F3_SLTU: alu_ctrl_enum = ALU_SLTU;
          F3_XOR: alu_ctrl_enum = ALU_XOR;
          F3_SRL_SRA: alu_ctrl_enum = ALU_SRL;
          F3_OR: alu_ctrl_enum = ALU_OR;
          F3_AND: alu_ctrl_enum = ALU_AND;
          default: ;
        endcase
      end
      ALU_OP_BRANCHES: begin
        case (func3_branch_enum)
          F3_BEQ, F3_BNE: begin
            alu_ctrl_enum = ALU_SUB;
          end
          F3_BLT, F3_BGE: begin
            alu_ctrl_enum = ALU_SLT;
          end
          F3_BLTU, F3_BGEU: begin
            alu_ctrl_enum = ALU_SLTU;
          end
          default: ;
        endcase
      end
      default: ;
    endcase
  end

  assign alu_ctrl = alu_ctrl_enum;

endmodule


/*
 * branch and jump controller
 *
 * rur1k 2025-08-04
 *
 */

module branch_jump_control (
    input [2:0] func3,
    input branch,
    input zero,
    input jump,
    output pc_sel
);

  branch_funct3_t func3_branch_enum;
  assign func3_branch_enum = branch_funct3_t'(func3);
  logic comparison_result;

  always @(*) begin
    case (func3_branch_enum)
      F3_BEQ:  comparison_result = zero;
      F3_BNE:  comparison_result = ~zero;
      F3_BLT:  comparison_result = ~zero;
      F3_BGE:  comparison_result = zero;
      F3_BLTU: comparison_result = ~zero;
      F3_BGEU: comparison_result = zero;
      default: comparison_result = 1'bx;
    endcase
  end

  assign pc_sel = (comparison_result & branch) | jump;

endmodule

module pipeline_controller ();

endmodule

module hazard_controller ();

endmodule

module forward_unit ();

endmodule


/*
 * STORE ALIGNER
 *
 * BRH 10/24
 *
 * Sits before the data memory and allows to feed the right signals into the memory's cpu interface.
 *
 * dev note 2025-08-04 (rur1k):
 * optimized the shifting process to a mux only process so i could use less
 * shifter resources
 *
 * dev note 2025-08-05 (rur1k):
 * changed the name of the module to the standard naming convention it is more
 * of a data aligner than a decoder and it is store only and doesn't care
 * about the load process
 */

module store_aligner (
    input  logic [31:0] alu_result_address,
    input  logic [ 2:0] f3,
    input  logic [31:0] reg_read,
    output logic [ 3:0] byte_enable,
    output logic [31:0] data
);

  logic [ 1:0] offset;
  logic [ 7:0] byte_store;
  logic [15:0] half_store;
  assign offset = alu_result_address[1:0];

  assign byte_store = reg_read & 32'h000000FF;
  assign half_store = reg_read & 32'h0000FFFF;

  always_comb begin
    case (f3)
      F3_BYTE, F3_BYTE_U: begin  // SB, LB, LBU
        case (offset)
          2'b00: begin
            byte_enable = 4'b0001;
            data = {24'b0, byte_store};
          end
          2'b01: begin
            byte_enable = 4'b0010;
            data = {16'b0, byte_store, 8'b0};
          end
          2'b10: begin
            byte_enable = 4'b0100;
            data = {8'b0, byte_store, 16'b0};
          end
          2'b11: begin
            byte_enable = 4'b1000;
            data = {byte_store, 24'b0};
          end
          default: begin
            data = 'b0;
            byte_enable = 4'b0000;
          end
        endcase
      end

      F3_WORD: begin  // SW
        byte_enable = (offset == 2'b00) ? 4'b1111 : 4'b0000;
        data = reg_read;
      end

      F3_HALFWORD, F3_HALFWORD_U: begin  // SH, LH, LHU
        case (offset)
          2'b00: begin
            byte_enable = 4'b0011;
            data = {16'b0, half_store};
          end
          2'b10: begin
            byte_enable = 4'b1100;
            data = {half_store, 16'b0};
          end
          default: begin
            data = 'b0;
            byte_enable = 4'b0000;
          end
        endcase
      end

      default: begin
        data = 'b0;
        byte_enable = 4'b0000;  // No operation for unsupported types
      end
    endcase
  end

endmodule


/*
 * LOAD ALIGNER
 *
 * BRH 10/24
 *
 * Reads incomming data from memory and formats it depending on the issued instruction's f3
 * and the bye_enable mask.
 *
 * dev note 2025-08-04 (rur1k):
 * changed the name of this module for the same reason mentioned for the
 * module store_aligner
 */

module load_aligner (
    input logic [31:0] mem_data,
    input logic [ 3:0] be_mask,
    input logic [ 2:0] f3,

    output logic [31:0] wb_data
);


  logic sign_extend;
  assign sign_extend = ~f3[2];

  logic [31:0] masked_data;  // just a mask applied
  logic [31:0] raw_data;  // Data shifted according to instruction
  // and then mem_data is the final output with sign extension

  always_comb begin : mask_apply
    for (int i = 0; i < 4; i++) begin
      if (be_mask[i]) begin
        masked_data[(i*8)+:8] = mem_data[(i*8)+:8];
      end else begin
        masked_data[(i*8)+:8] = 8'h00;
      end
    end
  end

  always_comb begin : shift_data
    case (f3)
      F3_WORD: raw_data = masked_data;  // masked data is full word in that case

      F3_BYTE, F3_BYTE_U: begin  // LB, LBU
        case (be_mask)
          4'b0001: raw_data = masked_data;
          4'b0010: raw_data = masked_data >> 8;
          4'b0100: raw_data = masked_data >> 16;
          4'b1000: raw_data = masked_data >> 24;
          default: raw_data = 32'd0;
        endcase
      end

      F3_HALFWORD, F3_HALFWORD_U: begin  // LH, LHU
        case (be_mask)
          4'b0011: raw_data = masked_data;
          4'b1100: raw_data = masked_data >> 16;
          default: raw_data = 32'd0;
        endcase
      end

      default: raw_data = 32'd0;
    endcase
  end

  always_comb begin : sign_extend_logic
    case (f3)
      // LW
      F3_WORD: wb_data = raw_data;

      // LB, LBU
      F3_BYTE, F3_BYTE_U: begin
        wb_data = sign_extend ? {{24{raw_data[7]}}, raw_data[7:0]} : raw_data;
      end

      // LH, LHU
      F3_HALFWORD, F3_HALFWORD_U: begin
        wb_data = sign_extend ? {{16{raw_data[15]}}, raw_data[15:0]} : raw_data;
      end

      default: wb_data = 32'd0;
    endcase
  end

endmodule


