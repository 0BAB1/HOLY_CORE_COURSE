/** axi_details
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : First wrapper for vivado to "demux" the axi interface into detailed signals
*   (Suitable for all targets)
*/

module axi_details (
    // CPU clock and active low reset
    input logic clk,
    input logic rst_n,

    // =================
    // Detailled AXI IF
    // =================

    // axi clock
    input logic aclk,
    input logic aresetn,
    
    // Write Address Channel
    output logic [3:0]               m_axi_awid,
    output logic [31:0]              m_axi_awaddr,
    output logic [7:0]               m_axi_awlen,
    output logic [2:0]               m_axi_awsize,
    output logic [1:0]               m_axi_awburst,
    output logic                     m_axi_awvalid,
    input  logic                     m_axi_awready,

    // Write Data Channel
    output logic [31:0]              m_axi_wdata, 
    output logic [3:0]               m_axi_wstrb,
    output logic                     m_axi_wlast,
    output logic                     m_axi_wvalid,
    input  logic                     m_axi_wready,

    // Write Response Channel
    input  logic [3:0]               m_axi_bid,
    input  logic [1:0]               m_axi_bresp,
    input  logic                     m_axi_bvalid,
    output logic                     m_axi_bready,

    // Read Address Channel
    output logic [3:0]               m_axi_arid,
    output logic [31:0]              m_axi_araddr,
    output logic [7:0]               m_axi_arlen,
    output logic [2:0]               m_axi_arsize,
    output logic [1:0]               m_axi_arburst,
    output logic                     m_axi_arvalid,
    input  logic                     m_axi_arready,

    // Read Data Channel
    input  logic [3:0]               m_axi_rid,
    input  logic [31:0]              m_axi_rdata,
    input  logic [1:0]               m_axi_rresp,
    input  logic                     m_axi_rlast,
    input  logic                     m_axi_rvalid,
    output logic                     m_axi_rready,

    // ========================
    // Detailled DEBUG SIGNALS
    // ========================

    // Core debug signals
    output logic [31:0] instruction,
    output logic [31:0] pc,
    output logic [31:0] pc_next,

    // Cache debug signals
    output logic [2:0] i_cache_state,
    output logic [2:0] d_cache_state, 
    output logic i_cache_stall,
    output logic d_cache_stall, 
    output logic [6:0] i_cache_set_ptr,
    output logic [6:0] i_next_set_ptr,
    output logic [6:0] d_cache_set_ptr,
    output logic [6:0] d_next_set_ptr
);

// INTERFACES DECLARATION
axi_if m_axi(); // axi master

holy_core core(
    .clk(clk), 
    .rst_n(rst_n),

    // AXI Master Interface
    .m_axi(m_axi),

    // Debug out interface
    .debug_pc(pc),  
    .debug_pc_next(pc_next),  
    .debug_instruction(instruction),  
    .debug_i_cache_state(i_cache_state),  
    .debug_d_cache_state(d_cache_state),
    .debug_i_set_ptr(i_cache_set_ptr),  
    .debug_i_next_set_ptr(i_next_set_ptr),
    .debug_d_set_ptr(d_cache_set_ptr),  
    .debug_d_next_set_ptr(d_next_set_ptr),
    .debug_i_cache_stall(i_cache_stall),  
    .debug_d_cache_stall(d_cache_stall)
);

// Connect the discrete AXI signals to the m_axi
assign m_axi.aclk       = aclk;
assign m_axi.aresetn    = aresetn;

// Write Address Channel
assign m_axi_awid       = m_axi.awid;
assign m_axi_awaddr     = m_axi.awaddr;
assign m_axi_awlen      = m_axi.awlen;
assign m_axi_awsize     = m_axi.awsize;
assign m_axi_awburst    = m_axi.awburst;
assign m_axi_awvalid    = m_axi.awvalid;
assign m_axi.awready    = m_axi_awready;


// Write Data Channel
assign m_axi_wdata   = m_axi.wdata;
assign m_axi_wstrb   = m_axi.wstrb;
assign m_axi_wlast   = m_axi.wlast;
assign m_axi_wvalid  = m_axi.wvalid;
assign m_axi.wready  = m_axi_wready;

// Write Response Channel
assign m_axi.bid    = m_axi_bid;
assign m_axi.bresp  = m_axi_bresp;
assign m_axi.bvalid = m_axi_bvalid;
assign m_axi_bready = m_axi.bready;

// Read Address Channel
assign m_axi_arid    = m_axi.arid;
assign m_axi_araddr  = m_axi.araddr;
assign m_axi_arlen   = m_axi.arlen;
assign m_axi_arsize  = m_axi.arsize;
assign m_axi_arburst = m_axi.arburst;
assign m_axi_arvalid = m_axi.arvalid;
assign m_axi.arready = m_axi_arready;

// Read Data Channel
assign m_axi.rid    = m_axi_rid;
assign m_axi.rdata  = m_axi_rdata;
assign m_axi.rresp  = m_axi_rresp;
assign m_axi.rlast  = m_axi_rlast;
assign m_axi.rvalid = m_axi_rvalid;
assign m_axi_rready = m_axi.rready;

endmodule