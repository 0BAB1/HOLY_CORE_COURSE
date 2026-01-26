import holy_core_pkg::*;

/*
 * register with clear
 *
 * rur1k 2025-08-04
 *
 * to use in pipelines
 */

module n_bit_reg_wclr #(
    parameter int N = 32
) (
    input logic clk,
    input logic rst_n,
    input logic wen,
    input logic clear,
    input logic [N-1:0] data_in,
    output logic [N-1:0] data_out
);

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n || clear) data_out <= 32'b0;
    else if (wen) data_out <= data_in;
  end
endmodule


/*
 * program counter
 *
 * rur1k 2025-08-04
 *
 * reason of seperation from other registers
 * to differentiate between normal registers and PC
 */

module program_counter (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic [31:0] next_pc,
    output logic [31:0] pc
);

  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) pc <= 32'b0;
    else if (en) pc <= next_pc;
  end
endmodule

/*
 * REGISTER FILE
 *
 * BRH 10/24
 *
 * Simple register file. RISC-V compliant.
 *
 * dev note 2025-08-04 (rur1k):
 * optimized register[0] so that it is hard wired to ground
 * and not an actual register
 *
 */

module regfile (
    // basic signals
    input logic clk,
    input logic rst_n,

    // Reads
    input  logic [ 4:0] rs1_addr,
    input  logic [ 4:0] rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,

    // Writes
    input logic write_enable,
    input logic [31:0] write_data,
    input logic [4:0] rd_addr
);

  // 32bits register. 32 of them (addressed with 5 bits)
  wire [31:0] registers  [0:31];
  reg  [31:0] registers_w[1:31];

  assign registers[0] = 0;
  // Write logic
  always @(posedge clk, negedge rst_n) begin
    // reset support, init to 0
    if (~rst_n) begin
      for (int i = 1; i < 32; i++) registers_w[i] <= 32'b0;
    end  // Write, except on 0, reserved for a zero constant according to RISC-V specs
    else if (write_enable) begin
      registers_w[rd_addr] <= write_data;
    end
  end

  assign registers[1:31] = registers_w[1:31];
  // Read logic, async
  assign rs1_data = registers[rs1_addr];
  assign rs2_data = registers[rs2_addr];
endmodule


/*
 * SIGN EXTENDER -> IMM GENERATOR
 *
 * BRH 10/24
 *
 * Extends the imm sign to 32bits based on source specified by the control unit.
 */

module imm_gen (
    // IN
    input logic [24:0] raw_src,
    input logic [ 2:0] imm_source,

    // OUT (immediate)
    output logic [31:0] immediate
);

  always_comb begin
    case (imm_source)
      // For I-Types
      3'b000:  immediate = {{20{raw_src[24]}}, raw_src[24:13]};
      // For S-types
      3'b001:  immediate = {{20{raw_src[24]}}, raw_src[24:18], raw_src[4:0]};
      // For B-types
      3'b010:  immediate = {{20{raw_src[24]}}, raw_src[0], raw_src[23:18], raw_src[4:1], 1'b0};
      // For J-types
      3'b011:  immediate = {{12{raw_src[24]}}, raw_src[12:5], raw_src[13], raw_src[23:14], 1'b0};
      // For U-Types
      3'b100:  immediate = {raw_src[24:5], 12'b000000000000};
      default: immediate = 32'd0;
    endcase
  end
endmodule


/*
 * simple adder subtractor
 *
 * can add and subtract based on one control signal (sub)
 *
 * dev note 2025-08-04 (rur1k):
 * optimized the add sub part of the alu so module elaboration wouldn't
 * generate three adders and only two
 *
 */

module adder_subtractor (
    input [31:0] a,
    input [31:0] b,
    input sub,
    output [31:0] add_sub_result
);

  wire [31:0] _b;
  assign _b = b ^ {32{sub}};
  assign add_sub_result = a + _b + sub;
endmodule


/*
 * HOLY CORE ALU
 *
 * BRH 10/24
 *
 * Simple and non efficient ALU.
 *
 * dev note 2025-08-04 (rur1k):
 * replaced the add and subtract part with the "adder_subtractor"
 * added in the datapath_utils.sv
 *
 * you can optimize the SLT and SLTU by just using the lower 31 bits and then
 * making the upper bit as the decider with a bit as the selector
 *
 */

module alu (
    // IN
    input logic [3:0] alu_control,
    input logic [31:0] src1,
    input logic [31:0] src2,
    // OUT
    output logic [31:0] alu_result,
    output logic zero
);


  wire [ 4:0] shamt = src2[4:0];
  wire [31:0] add_sub_out;

  adder_subtractor add_sub_unit (
      .a(src1),
      .b(src2),
      .sub(alu_control[0]),
      .add_sub_result(add_sub_out)
  );
  alu_control_t alu_control_enum;
  assign alu_control_enum = alu_control_t'(alu_control);
  always_comb begin
    case (alu_control_enum)
      ALU_ADD:  alu_result = add_sub_out;
      ALU_AND:  alu_result = src1 & src2;
      ALU_OR:   alu_result = src1 | src2;
      ALU_SUB:  alu_result = add_sub_out;
      ALU_SLT:  alu_result = {31'b0, $signed(src1) < $signed(src2)};
      ALU_SLTU: alu_result = {31'b0, src1 < src2};
      ALU_XOR:  alu_result = src1 ^ src2;
      ALU_SLL:  alu_result = src1 << shamt;
      ALU_SRL:  alu_result = src1 >> shamt;
      ALU_SRA:  alu_result = $signed(src1) >>> shamt;
      default:  alu_result = 32'd0;
    endcase
  end

  assign zero = ~(|alu_result);
endmodule
