/** holy_test_harness
*
*   Author : BABIN-RIBY Hugo
*   Project : Holy Core V2
*   Description : This is just an "axi_translator" wapper module.aclk
*   This wrapper module instantiates the cache and routes the AXI interface as discrete Verilog signals for cocotb
*/

module holy_test_harness (
    // CPU clock and active low reset
    input logic clk,
    input logic rst_n,

    // axi clock
    input logic aclk,
    input logic aresetn,

    //=======================
    // AXI FULL Interface
    //=======================
    
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

    //=======================
    // AXI-Lite Interface
    //=======================
    output logic [31:0] m_axi_lite_awaddr,
    output logic        m_axi_lite_awvalid,
    input  logic        m_axi_lite_awready,

    output logic [31:0] m_axi_lite_wdata,
    output logic [3:0]  m_axi_lite_wstrb,
    output logic        m_axi_lite_wvalid,
    input  logic        m_axi_lite_wready,

    input  logic [1:0]  m_axi_lite_bresp,
    input  logic        m_axi_lite_bvalid,
    output logic        m_axi_lite_bready,

    output logic [31:0] m_axi_lite_araddr,
    output logic        m_axi_lite_arvalid,
    input  logic        m_axi_lite_arready,

    input  logic [31:0] m_axi_lite_rdata,
    input  logic [1:0]  m_axi_lite_rresp,
    input  logic        m_axi_lite_rvalid,
    output logic        m_axi_lite_rready
);

axi_if m_axi();
axi_lite_if m_axi_lite();

/* verilator lint_off PINMISSING */
holy_core core(
    .clk(clk), 
    .rst_n(rst_n),

    // AXI Master Interface
    .m_axi(m_axi),
    .m_axi_lite(m_axi_lite)

    // We don't use debug signals in tb
    // ...
);
/* verilator lint_on PINMISSING */

//=======================
// AXI FULL Interface
//=======================

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

//=======================
// AXI-Lite Interface
//=======================

// Connect AXI-Lite signals
assign m_axi_lite_awaddr  = m_axi_lite.awaddr;
assign m_axi_lite_awvalid = m_axi_lite.awvalid;
assign m_axi_lite.awready = m_axi_lite_awready;

assign m_axi_lite_wdata   = m_axi_lite.wdata;
assign m_axi_lite_wstrb   = m_axi_lite.wstrb;
assign m_axi_lite_wvalid  = m_axi_lite.wvalid;
assign m_axi_lite.wready  = m_axi_lite_wready;

assign m_axi_lite.bresp   = m_axi_lite_bresp;
assign m_axi_lite.bvalid  = m_axi_lite_bvalid;
assign m_axi_lite_bready  = m_axi_lite.bready;

assign m_axi_lite_araddr  = m_axi_lite.araddr;
assign m_axi_lite_arvalid = m_axi_lite.arvalid;
assign m_axi_lite.arready = m_axi_lite_arready;

assign m_axi_lite.rdata   = m_axi_lite_rdata;
assign m_axi_lite.rresp   = m_axi_lite_rresp;
assign m_axi_lite.rvalid  = m_axi_lite_rvalid;
assign m_axi_lite_rready  = m_axi_lite.rready;

endmodule