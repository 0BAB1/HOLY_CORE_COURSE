/* AXI_TRANSLATOR
*
* BRH 11/24
*
* This wrapper module instantiates the cache and routes the AXI interface as discrete Verilog signals for cocotb
*/

import holy_core_pkg::*;

module axi_translator (
    // ====================
    // Clock and reset are only here to be passed to the external Axi module in the simulations

    input logic clk, 
    input logic rst_n,

    // ====================
    // MASTER

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

    // ====================
    // INSTRCTION SLAVE

    // Write Address Channel
    input  logic [3:0]               s_axi_instr_awid,
    input  logic [31:0]              s_axi_instr_awaddr,
    input  logic [7:0]               s_axi_instr_awlen,
    input  logic [2:0]               s_axi_instr_awsize,
    input  logic [1:0]               s_axi_instr_awburst,
    input  logic                     s_axi_instr_awvalid,
    output logic                     s_axi_instr_awready,

    // Write Data Channel
    input  logic [31:0]              s_axi_instr_wdata, 
    input  logic [3:0]               s_axi_instr_wstrb,
    input  logic                     s_axi_instr_wlast,
    input  logic                     s_axi_instr_wvalid,
    output logic                     s_axi_instr_wready,

    // Write Response Channel
    output logic [3:0]               s_axi_instr_bid,
    output logic [1:0]               s_axi_instr_bresp,
    output logic                     s_axi_instr_bvalid,
    input  logic                     s_axi_instr_bready,

    // Read Address Channel
    input  logic [3:0]               s_axi_instr_arid,
    input  logic [31:0]              s_axi_instr_araddr,
    input  logic [7:0]               s_axi_instr_arlen,
    input  logic [2:0]               s_axi_instr_arsize,
    input  logic [1:0]               s_axi_instr_arburst,
    input  logic                     s_axi_instr_arvalid,
    output logic                     s_axi_instr_arready,

    // Read Data Channel
    output logic [3:0]               s_axi_instr_rid,
    output logic [31:0]              s_axi_instr_rdata,
    output logic [1:0]               s_axi_instr_rresp,
    output logic                     s_axi_instr_rlast,
    output logic                     s_axi_instr_rvalid,
    input  logic                     s_axi_instr_rready,


    // ====================
    // DATA SLAVE

    // Write Address Channel
    input  logic [3:0]               s_axi_data_awid,
    input  logic [31:0]              s_axi_data_awaddr,
    input  logic [7:0]               s_axi_data_awlen,
    input  logic [2:0]               s_axi_data_awsize,
    input  logic [1:0]               s_axi_data_awburst,
    input  logic                     s_axi_data_awvalid,
    output logic                     s_axi_data_awready,

    // Write Data Channel
    input  logic [31:0]              s_axi_data_wdata, 
    input  logic [3:0]               s_axi_data_wstrb,
    input  logic                     s_axi_data_wlast,
    input  logic                     s_axi_data_wvalid,
    output logic                     s_axi_data_wready,

    // Write Response Channel
    output logic [3:0]               s_axi_data_bid,
    output logic [1:0]               s_axi_data_bresp,
    output logic                     s_axi_data_bvalid,
    input  logic                     s_axi_data_bready,

    // Read Address Channel
    input  logic [3:0]               s_axi_data_arid,
    input  logic [31:0]              s_axi_data_araddr,
    input  logic [7:0]               s_axi_data_arlen,
    input  logic [2:0]               s_axi_data_arsize,
    input  logic [1:0]               s_axi_data_arburst,
    input  logic                     s_axi_data_arvalid,
    output logic                     s_axi_data_arready,

    // Read Data Channel
    output logic [3:0]               s_axi_data_rid,
    output logic [31:0]              s_axi_data_rdata,
    output logic [1:0]               s_axi_data_rresp,
    output logic                     s_axi_data_rlast,
    output logic                     s_axi_data_rvalid,
    input  logic                     s_axi_data_rready,

    // ======================
    // CACHE STATES STIMULUS

    input cache_state_t instr_cache_state,
    input cache_state_t data_cache_state
    
);

    // ====================
    // MASTER

    // Declare the AXI master interface for the cache
    axi_if m_axi();

    // Write Address Channel
    assign m_axi_awid       = m_axi.awid;
    assign m_axi_awaddr     = m_axi.awaddr;
    assign m_axi_awlen      = m_axi.awlen;
    assign m_axi_awsize     = m_axi.awsize;
    assign m_axi_awburst    = m_axi.awburst;
    assign m_axi_awvalid    = m_axi.awvalid;
    assign m_axi.awready = m_axi_awready;


    // Write Data Channel
    assign m_axi_wdata   = m_axi.wdata;
    assign m_axi_wstrb   = m_axi.wstrb;
    assign m_axi_wlast   = m_axi.wlast;
    assign m_axi_wvalid  = m_axi.wvalid;
    assign m_axi.wready = m_axi_wready;

    // Write Response Channel
    assign m_axi.bid    = m_axi_bid;
    assign m_axi.bresp  = m_axi_bresp;
    assign m_axi.bvalid = m_axi_bvalid;
    assign m_axi_bready             = m_axi.bready;

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
    assign m_axi_rready   = m_axi.rready;

    // ====================
    // INSTRUCTION SLAVE

    axi_if s_axi_instr();

    // Write Address Channel
    assign s_axi_instr.awid     = s_axi_instr_awid;
    assign s_axi_instr.awaddr   = s_axi_instr_awaddr;
    assign s_axi_instr.awlen    = s_axi_instr_awlen;
    assign s_axi_instr.awsize   = s_axi_instr_awsize;
    assign s_axi_instr.awburst  = s_axi_instr_awburst;
    assign s_axi_instr.awvalid  = s_axi_instr_awvalid;
    assign s_axi_instr_awready    = s_axi_instr.awready;

    // Write Data Channel
    assign s_axi_instr.wdata    = s_axi_instr_wdata;
    assign s_axi_instr.wstrb    = s_axi_instr_wstrb;
    assign s_axi_instr.wlast    = s_axi_instr_wlast;
    assign s_axi_instr.wvalid   = s_axi_instr_wvalid;
    assign s_axi_instr_wready     = s_axi_instr.wready;

    // Write Response Channel
    assign s_axi_instr_bid        = s_axi_instr.bid;
    assign s_axi_instr_bresp      = s_axi_instr.bresp;
    assign s_axi_instr_bvalid     = s_axi_instr.bvalid;
    assign s_axi_instr.bready   = s_axi_instr_bready;

    // Read Address Channel
    assign s_axi_instr.arid     = s_axi_instr_arid;
    assign s_axi_instr.araddr   = s_axi_instr_araddr;
    assign s_axi_instr.arlen    = s_axi_instr_arlen;
    assign s_axi_instr.arsize   = s_axi_instr_arsize;
    assign s_axi_instr.arburst  = s_axi_instr_arburst;
    assign s_axi_instr.arvalid  = s_axi_instr_arvalid;
    assign s_axi_instr_arready    = s_axi_instr.arready;

    // Read Data Channel
    assign s_axi_instr_rid        = s_axi_instr.rid;
    assign s_axi_instr_rdata      = s_axi_instr.rdata;
    assign s_axi_instr_rresp      = s_axi_instr.rresp;
    assign s_axi_instr_rlast      = s_axi_instr.rlast;
    assign s_axi_instr_rvalid     = s_axi_instr.rvalid;
    assign s_axi_instr.rready   = s_axi_instr_rready;

    // ====================
    // DATA SLAVE

    axi_if s_axi_data();

    // Write Address Channel
    assign s_axi_data.awid     = s_axi_data_awid;
    assign s_axi_data.awaddr   = s_axi_data_awaddr;
    assign s_axi_data.awlen    = s_axi_data_awlen;
    assign s_axi_data.awsize   = s_axi_data_awsize;
    assign s_axi_data.awburst  = s_axi_data_awburst;
    assign s_axi_data.awvalid  = s_axi_data_awvalid;
    assign s_axi_data_awready    = s_axi_data.awready;

    // Write Data Channel
    assign s_axi_data.wdata    = s_axi_data_wdata;
    assign s_axi_data.wstrb    = s_axi_data_wstrb;
    assign s_axi_data.wlast    = s_axi_data_wlast;
    assign s_axi_data.wvalid   = s_axi_data_wvalid;
    assign s_axi_data_wready     = s_axi_data.wready;

    // Write Response Channel
    assign s_axi_data_bid        = s_axi_data.bid;
    assign s_axi_data_bresp      = s_axi_data.bresp;
    assign s_axi_data_bvalid     = s_axi_data.bvalid;
    assign s_axi_data.bready   = s_axi_data_bready;

    // Read Address Channel
    assign s_axi_data.arid     = s_axi_data_arid;
    assign s_axi_data.araddr   = s_axi_data_araddr;
    assign s_axi_data.arlen    = s_axi_data_arlen;
    assign s_axi_data.arsize   = s_axi_data_arsize;
    assign s_axi_data.arburst  = s_axi_data_arburst;
    assign s_axi_data.arvalid  = s_axi_data_arvalid;
    assign s_axi_data_arready    = s_axi_data.arready;

    // Read Data Channel
    assign s_axi_data_rid        = s_axi_data.rid;
    assign s_axi_data_rdata      = s_axi_data.rdata;
    assign s_axi_data_rresp      = s_axi_data.rresp;
    assign s_axi_data_rlast      = s_axi_data.rlast;
    assign s_axi_data_rvalid     = s_axi_data.rvalid;
    assign s_axi_data.rready   = s_axi_data_rready;


    // Instantiate the cache module
    external_req_arbitrer #(
    ) external_req_arbitrer_instance (
        // AXI Master Interface
        .m_axi(m_axi),
        // AXI Slaves Interfaces
        .s_axi_instr(s_axi_instr),
        .s_axi_data(s_axi_data),

        // chaches states stimulus
        .i_cache_state(instr_cache_state),
        .d_cache_state(data_cache_state)
    );

endmodule
