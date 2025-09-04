/** holy_top
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : Second wrapper for vivado, serves as plain verilog top module.
*   (Suitable for all targets)
*/

module holy_wrapper #(
    parameter DEBUG_EN = 1
)(
    input wire clk,
    input wire rst_n,
    input wire aclk,
    input wire aresetn,

    // AXI FULL interface
    output wire [3:0]               m_axi_awid,
    output wire [31:0]              m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [31:0]              m_axi_wdata, 
    output wire [3:0]               m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [3:0]               m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,
    output wire [3:0]               m_axi_arid,
    output wire [31:0]              m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [3:0]               m_axi_rid,
    input  wire [31:0]              m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready,

    // AXI LITE interface
    output wire [31:0]              m_axi_lite_awaddr,
    output wire                     m_axi_lite_awvalid,
    input  wire                     m_axi_lite_awready,
    output wire [31:0]              m_axi_lite_wdata,
    output wire [3:0]               m_axi_lite_wstrb,
    output wire                     m_axi_lite_wvalid,
    input  wire                     m_axi_lite_wready,
    input  wire [1:0]               m_axi_lite_bresp,
    input  wire                     m_axi_lite_bvalid,
    output wire                     m_axi_lite_bready,
    output wire [31:0]              m_axi_lite_araddr,
    output wire                     m_axi_lite_arvalid,
    input  wire                     m_axi_lite_arready,
    input  wire [31:0]              m_axi_lite_rdata,
    input  wire [1:0]               m_axi_lite_rresp,
    input  wire                     m_axi_lite_rvalid,
    output wire                     m_axi_lite_rready,

    // Debug OUT
    output wire [31:0]              pc,
    output wire [31:0]              pc_next,
    //output wire                     pc_source,
    output wire [31:0]              instruction,
    //output wire [3:0]               i_cache_state,
    //output wire [3:0]               d_cache_state,
    output wire                     i_cache_stall,
    output wire                     d_cache_stall,
    //output wire [6:0]               i_cache_set_ptr,
    //output wire [6:0]               d_cache_set_ptr,
    //output wire [6:0]               i_next_set_ptr,
    //output wire [6:0]               d_next_set_ptr,
    //output wire                     csr_flush_order,

    //output wire                     d_cache_seq_stall,
    //output wire                     d_cache_comb_stall,
    //output wire [3:0]               d_cache_next_state,
    //output wire                     mem_read,
    //output wire [3:0]               mem_byte_en,
    //output wire [31:0]              wb_data,

    // INTERRUPTS
    input wire ext_irq,
    input wire timer_irq,
    input wire soft_irq
);

// Internal wiring
axi_details wrapped (
    // System signals
    .clk(clk),
    .rst_n(rst_n),
    .aclk(aclk),
    .aresetn(aresetn),

    // AXI FULL
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr), 
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata), 
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),

    // AXI LITE
    .m_axi_lite_awaddr(m_axi_lite_awaddr),
    .m_axi_lite_awvalid(m_axi_lite_awvalid),
    .m_axi_lite_awready(m_axi_lite_awready),
    .m_axi_lite_wdata(m_axi_lite_wdata),
    .m_axi_lite_wstrb(m_axi_lite_wstrb),
    .m_axi_lite_wvalid(m_axi_lite_wvalid),
    .m_axi_lite_wready(m_axi_lite_wready),
    .m_axi_lite_bresp(m_axi_lite_bresp),
    .m_axi_lite_bvalid(m_axi_lite_bvalid),
    .m_axi_lite_bready(m_axi_lite_bready),
    .m_axi_lite_araddr(m_axi_lite_araddr),
    .m_axi_lite_arvalid(m_axi_lite_arvalid),
    .m_axi_lite_arready(m_axi_lite_arready),
    .m_axi_lite_rdata(m_axi_lite_rdata),
    .m_axi_lite_rresp(m_axi_lite_rresp),
    .m_axi_lite_rvalid(m_axi_lite_rvalid),
    .m_axi_lite_rready(m_axi_lite_rready),

    // Debug
    .pc(pc),  
    .pc_next(pc_next),
    //.pc_source(pc_source),
    .instruction(instruction),  
    //.i_cache_state(i_cache_state),  
    //.d_cache_state(d_cache_state),
    //.i_cache_set_ptr(i_cache_set_ptr),  
    //.d_cache_set_ptr(d_cache_set_ptr),  
    .i_cache_stall(i_cache_stall),  
    //.i_next_set_ptr(i_next_set_ptr),
    .d_cache_stall(d_cache_stall),
    //.d_next_set_ptr(d_next_set_ptr),
    //.csr_flush_order(csr_flush_order),

    //.d_cache_seq_stall(d_cache_seq_stall),
    //.d_cache_comb_stall(d_cache_comb_stall),
    //.d_cache_next_state(d_cache_next_state),
    //.mem_read(mem_read),
    //.mem_byte_en(mem_byte_en),
    //.wb_data(wb_data),

    // IRQs
    .ext_irq(ext_irq),
    .timer_irq(timer_irq),
    .soft_irq(soft_irq)
);

endmodule
