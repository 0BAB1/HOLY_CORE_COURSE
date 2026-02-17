import holy_core_pkg::*;


/*
 * core
 *
 * rur1k 2025-08-04
 *
 * dev note 2025-08-04 (rur1k):
 * welcome to the datapath/controller mess :)
 *
 */

module core (
    input logic clk,
    input logic rst_n,
    input logic [31:0] inst_if,

    input logic [31:0] mem_read_data,

    output logic [3:0] byte_mask_mem,
    output logic [31:0] mem_addr_mem,
    output logic [31:0] mem_write_data,
    output logic mem_write_mem,

    output logic [31:0] current_pc_if
);


  logic if_id_reg_en;
  logic id_exe_reg_en;
  logic exe_mem_reg_en;
  logic mem_wb_reg_en;
  logic if_id_reg_clr;
  logic id_exe_reg_clr;
  logic exe_mem_reg_clr;
  logic mem_wb_reg_clr;

  assign if_id_reg_en = 1'b1;
  assign id_exe_reg_en = 1'b1;
  assign exe_mem_reg_en = 1'b1;
  assign mem_wb_reg_en = 1'b1;
  assign if_id_reg_clr = 1'b0;
  assign id_exe_reg_clr = 1'b0;
  assign exe_mem_reg_clr = 1'b0;
  assign mem_wb_reg_clr = 1'b0;

  logic pc_en;
  logic [31:0] next_pc;
  logic [31:0] pc_plus_4_if;
  assign pc_en = 1'b1;
  program_counter PC_inst (
      .clk(clk),
      .rst_n(rst_n),
      .en(pc_en),
      .next_pc(next_pc),
      .pc(current_pc_if)
  );


  assign pc_plus_4_if = current_pc_if + 32'd4;
  logic pc_sel_mem;
  assign next_pc = pc_sel_mem ? pc_jump_mem : pc_plus_4_if;

  if_id_reg_t if_id_in;
  if_id_reg_t if_id_out;
  assign if_id_in.inst = inst_if;
  assign if_id_in.current_pc = current_pc_if;
  assign if_id_in.pc_plus_4 = pc_plus_4_if;




  n_bit_reg_wclr #(
      .N($size(if_id_reg_t))
  ) if_id_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .wen(if_id_reg_en),
      .clear(if_id_reg_clr),
      .data_in(if_id_in),
      .data_out(if_id_out)
  );



  logic [31:0] inst_id;
  logic [31:0] current_pc_id;
  logic [31:0] pc_plus_4_id;
  assign inst_id = if_id_out.inst;
  assign current_pc_id = if_id_out.current_pc;
  assign pc_plus_4_id = if_id_out.pc_plus_4;


  logic [ 2:0] func3_id;
  logic [ 6:0] func7_id;
  logic [ 6:0] opcode_id;
  logic [ 4:0] rs1_addr_id;
  logic [ 4:0] rs2_addr_id;
  logic [ 4:0] rd_addr_id;
  logic [31:0] imm_id;

  assign func3_id = inst_id[14:12];
  assign func7_id = inst_id[31:25];
  assign opcode_id = inst_id[6:0];
  assign rs1_addr_id = inst_id[19:15];
  assign rs2_addr_id = inst_id[24:20];
  assign rd_addr_id = inst_id[11:7];


  logic [31:0] rd_data_wb;
  logic [31:0] rs1_data_id;
  logic [31:0] rs2_data_id;


  regfile regfile_inst (
      .clk  (clk),
      .rst_n(rst_n),

      .rs1_addr(rs1_addr_id),
      .rs2_addr(rs2_addr_id),
      .rs1_data(rs1_data_id),
      .rs2_data(rs2_data_id),

      .write_enable(reg_write_wb),
      .write_data(rd_data_wb),
      .rd_addr(rd_addr_wb)
  );


  logic mem_write_id;
  logic reg_write_id;
  logic alu_source_id;
  logic [2:0] imm_source_id;
  logic [1:0] alu_op_id;
  logic r_type_id;
  logic branch_id;
  logic jump_id;
  logic jalr_id;
  logic lui_id;
  logic auipc_id;
  logic mem_to_reg_id;

  main_control main_control_inst (
      // IN
      .opcode(opcode_id),
      .mem_write(mem_write_id),
      .reg_write(reg_write_id),
      .alu_source(alu_source_id),
      .imm_source(imm_source_id),
      .alu_op(alu_op_id),
      .r_type(r_type_id),
      .branch(branch_id),
      .jump(jump_id),
      .jalr(jalr_id),
      .lui(lui_id),
      .auipc(auipc_id),
      .mem_to_reg(mem_to_reg_id)
  );



  imm_gen imm_gen_inst (
      // IN
      .raw_src(inst_id[31:7]),
      .imm_source(imm_source_id),
      .immediate(imm_id)
  );

  id_exe_reg_t id_exe_in;
  id_exe_reg_t id_exe_out;

  assign id_exe_in.current_pc = current_pc_id;
  assign id_exe_in.pc_plus_4 = pc_plus_4_id;
  assign id_exe_in.rs1_addr = rs1_addr_id;
  assign id_exe_in.rs2_addr = rs2_addr_id;
  assign id_exe_in.rd_addr = rd_addr_id;
  assign id_exe_in.rs1_data = rs1_data_id;
  assign id_exe_in.rs2_data = rs2_data_id;
  assign id_exe_in.func3 = func3_id;
  assign id_exe_in.func7 = func7_id;
  assign id_exe_in.imm = imm_id;

  assign id_exe_in.reg_write = reg_write_id;
  assign id_exe_in.mem_write = mem_write_id;
  assign id_exe_in.mem_to_reg = mem_to_reg_id;
  assign id_exe_in.branch = branch_id;
  assign id_exe_in.alu_src = alu_source_id;
  assign id_exe_in.jump = jump_id;
  assign id_exe_in.lui = lui_id;
  assign id_exe_in.auipc = auipc_id;
  assign id_exe_in.jalr = jalr_id;
  assign id_exe_in.alu_op = alu_op_id;

  n_bit_reg_wclr #(
      .N($size(id_exe_reg_t))
  ) id_exe_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .wen(id_exe_reg_en),
      .clear(id_exe_reg_clr),
      .data_in(id_exe_in),
      .data_out(id_exe_out)
  );


  logic [31:0] current_pc_exe, pc_plus_4_exe;
  logic [4:0] rs1_addr_exe;
  logic [4:0] rs2_addr_exe;
  logic [4:0] rd_addr_exe;
  logic [31:0] rs1_data_exe;
  logic [31:0] rs2_data_exe;
  logic [2:0] func3_exe;
  logic [6:0] func7_exe;
  logic [31:0] imm_exe;

  logic reg_write_exe;
  logic mem_write_exe;
  logic mem_to_reg_exe;
  logic branch_exe;
  logic alu_source_exe;
  logic jump_exe;
  logic lui_exe;
  logic auipc_exe;
  logic jalr_exe;
  logic [1:0] alu_op_exe;


  assign current_pc_exe = id_exe_out.current_pc;
  assign pc_plus_4_exe = id_exe_out.pc_plus_4;
  assign rs1_addr_exe = id_exe_out.rs1_addr;
  assign rs2_addr_exe = id_exe_out.rs2_addr;
  assign rd_addr_exe = id_exe_out.rd_addr;
  assign rs1_data_exe = id_exe_out.rs1_data;
  assign rs2_data_exe = id_exe_out.rs2_data;
  assign func3_exe = id_exe_out.func3;
  assign func7_exe = id_exe_out.func7;
  assign imm_exe = id_exe_out.imm;

  assign reg_write_exe = id_exe_out.reg_write;
  assign mem_write_exe = id_exe_out.mem_write;
  assign mem_to_reg_exe = id_exe_out.mem_to_reg;
  assign branch_exe = id_exe_out.branch;
  assign alu_source_exe = id_exe_out.alu_src;
  assign jump_exe = id_exe_out.jump;
  assign lui_exe = id_exe_out.lui;
  assign auipc_exe = id_exe_out.auipc;
  assign jalr_exe = id_exe_out.jalr;
  assign alu_op_exe = id_exe_out.alu_op;

  logic [31:0] rdata1_frw_exe;
  logic [31:0] rdata2_frw_exe;
  logic [31:0] alu_src1;
  logic [31:0] alu_src2;
  logic [31:0] alu_result_exe;
  logic [31:0] pc_jump_exe;
  logic zero_exe;
  logic [31:0] jump_base_value;

  assign alu_src1 = auipc_exe ? current_pc_exe : rs1_data_exe;
  assign alu_src2 = alu_source_exe ? imm_exe : rs2_data_exe;

  assign jump_base_value = jalr_exe ? rs1_data_exe : current_pc_exe;
  assign pc_jump_exe = jump_base_value + (imm_exe & ~32'd1);

  logic [3:0] alu_ctrl_exe;

  alu_control alu_control_inst (
      .alu_op(alu_op_exe),
      .func3(func3_exe),
      .func7(func7_exe),
      .alu_ctrl(alu_ctrl_exe)
  );
  assign rdata2_frw_exe = rs2_data_exe;

  alu alu_inst (
      // IN
      .alu_control(alu_ctrl_exe),
      .src1(alu_src1),
      .src2(alu_src2),
      // OUT
      .alu_result(alu_result_exe),
      .zero(zero_exe)
  );

  exe_mem_reg_t exe_mem_in;
  exe_mem_reg_t exe_mem_out;
  assign exe_mem_in.current_pc = current_pc_exe;
  assign exe_mem_in.pc_plus_4 = pc_plus_4_exe;
  assign exe_mem_in.pc_jump = pc_jump_exe;
  assign exe_mem_in.rs2_addr = rs2_addr_exe;
  assign exe_mem_in.rd_addr = rd_addr_exe;
  assign exe_mem_in.func3 = func3_exe;
  assign exe_mem_in.rdata2_frw = rdata2_frw_exe;
  assign exe_mem_in.imm = imm_exe;
  assign exe_mem_in.alu_result = alu_result_exe;

  assign exe_mem_in.reg_write = reg_write_exe;
  assign exe_mem_in.mem_write = mem_write_exe;
  assign exe_mem_in.mem_to_reg = mem_to_reg_exe;
  assign exe_mem_in.branch = branch_exe;
  assign exe_mem_in.jump = jump_exe;
  assign exe_mem_in.lui = lui_exe;
  assign exe_mem_in.zero = zero_exe;

  n_bit_reg_wclr #(
      .N($size(exe_mem_reg_t))
  ) exe_mem_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .wen(exe_mem_reg_en),
      .clear(exe_mem_reg_clr),
      .data_in(exe_mem_in),
      .data_out(exe_mem_out)
  );

  // logic [31:0] rdata2_frw_exe;
  logic [31:0] pc_plus_4_mem;
  logic [31:0] pc_jump_mem;
  logic [4:0] rs2_addr_mem;
  logic [4:0] rd_addr_mem;
  logic [2:0] func3_mem;
  logic [31:0] rdata2_frw_mem;
  logic [31:0] imm_mem;
  logic [31:0] alu_result_mem;
  logic [31:0] mem_to_reg_data_mem;
  // Control signals
  logic reg_write_mem;
  logic mem_write_mem;
  logic mem_to_reg_mem;
  logic branch_mem;
  logic jump_mem;
  logic lui_mem;
  logic zero_mem;

  logic [31:0] current_pc_mem;
  assign current_pc_mem = exe_mem_out.current_pc;
  assign pc_plus_4_mem = exe_mem_out.pc_plus_4;
  assign pc_jump_mem = exe_mem_out.pc_jump;
  assign rs2_addr_mem = exe_mem_out.rs2_addr;
  assign rd_addr_mem = exe_mem_out.rd_addr;
  assign func3_mem = exe_mem_out.func3;
  assign rdata2_frw_mem = exe_mem_out.rdata2_frw;
  assign imm_mem = exe_mem_out.imm;
  assign alu_result_mem = exe_mem_out.alu_result;

  assign reg_write_mem = exe_mem_out.reg_write;
  assign mem_write_mem = exe_mem_out.mem_write;
  assign mem_to_reg_mem = exe_mem_out.mem_to_reg;
  assign branch_mem = exe_mem_out.branch;
  assign jump_mem = exe_mem_out.jump;
  assign lui_mem = exe_mem_out.lui;
  assign zero_mem = exe_mem_out.zero;


  logic [31:0] result_1_mem;
  logic [31:0] result_mem;
  assign result_1_mem = lui_mem ? imm_mem : alu_result_mem;
  assign result_mem   = jump_mem ? pc_plus_4_mem : result_1_mem;
  store_aligner store_aligner_inst (
      .alu_result_address(alu_result_mem),
      .f3(func3_mem),
      .reg_read(rdata2_frw_mem),
      .byte_enable(byte_mask_mem),
      .data(mem_write_data)
  );

  assign mem_addr_mem = alu_result_mem;

  branch_jump_control branch_jump_controller_inst (
      .func3 (func3_mem),
      .branch(branch_mem),
      .zero  (zero_mem),
      .jump  (jump_mem),
      .pc_sel(pc_sel_mem)
  );

  load_aligner load_aligner_inst (
      .mem_data(mem_read_data),
      .be_mask(byte_mask_mem),
      .f3(func3_mem),
      .wb_data(mem_to_reg_data_mem)
  );

  mem_wb_reg_t mem_wb_in;
  mem_wb_reg_t mem_wb_out;
  //
  assign mem_wb_in.mem_to_reg_data = mem_to_reg_data_mem;
  assign mem_wb_in.rd_addr = rd_addr_mem;
  assign mem_wb_in.result = result_mem;

  assign mem_wb_in.reg_write = reg_write_mem;
  assign mem_wb_in.mem_to_reg = mem_to_reg_mem;

  n_bit_reg_wclr #(
      .N($size(mem_wb_reg_t))
  ) mem_wb_reg_inst (
      .clk(clk),
      .rst_n(rst_n),
      .wen(mem_wb_reg_en),
      .clear(mem_wb_reg_clr),
      .data_in(mem_wb_in),
      .data_out(mem_wb_out)
  );

  logic [4:0] rd_addr_wb;
  logic [31:0] mem_to_reg_data_wb;
  logic [31:0] result_wb;

  // Control signals
  logic reg_write_wb;
  logic mem_to_reg_wb;

  assign mem_to_reg_data_wb = mem_wb_out.mem_to_reg_data;
  assign rd_addr_wb = mem_wb_out.rd_addr;
  assign result_wb = mem_wb_out.result;

  assign reg_write_wb = mem_wb_out.reg_write;
  assign mem_to_reg_wb = mem_wb_out.mem_to_reg;

  assign rd_data_wb = mem_to_reg_wb ? mem_to_reg_data_wb : result_wb;

endmodule

