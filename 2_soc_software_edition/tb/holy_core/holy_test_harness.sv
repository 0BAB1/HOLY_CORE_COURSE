/** holy_test_harness
*
*   Author : BABIN-RIBY Hugo
*
*   Description : The main HOLY CORE TESTBENCH
*                 Includes basic Components (Core, PLIC, CLINT)
*                 and an external AXI / ALITE interfaces to
*                 get data and instructions from external AXI
*                 compliant RAM hich are simulated by cocotb.
*
*   NOTE :        Terms CB and XBAR refers to the term "crossabr",
*                 a central element to this TB which route AXI LITE
*                 lite transaction to the right componenet.
*
*   BRH 07/25
*/

parameter NUM_IRQS = 5;

/**
* ==============
* Testbench MEMORY MAP
* (Not meant to be coherent, just raw testing)
* ==============
*
* 0xFFFF
* PLIC Module registers
* 0xF000
* ==============
*
* 0xEFFF
* CLINT Module registers
* 0x3000
* ==============
*
* 0x2FFF
* Trap handler code
* 0x2000
* ==============
*
* 0x1FFF
* Data
* 0x1000 (stored in gp : x3)
* ==============
*
* 0x0FFF
* Instructions
* 0x0000
* ==============
**/

import axi_pkg::*;

module holy_test_harness (
    // CPU clock and active low reset
    input logic clk,
    input logic rst_n,

    // axi clock
    input logic aclk,
    input logic aresetn,

    // In reality, clk and aclk are the same as CDC
    // is not supported in holy core's inner cache

    //===================================
    // TOP AXI FULL Interface
    // (for cocotb simulated components)
    //===================================
    
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

    //===================================
    // TOP AXI FULL Interface
    // (for cocotb simulated components)
    // AXIL CROSSBAR <=> COCOTB RAM
    //===================================

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
    output logic        m_axi_lite_rready,

    // External peripheral interrupts
    input  logic [NUM_IRQS-1:0]        irq_in
);

// TB slaves:
//  - coctb simulated ram
//  - PLIC
//  - CLINT
localparam SLV_NB = 3;

//=========================
// INTERFACES DECLARATIONS
//=========================

// HOLY CORE AXI FULL <=> EXTERNAL RAM
axi_if m_axi();
// HOLYCORE <=> AXIL CROSSBAR
axi_lite_if m_axi_lite();
// AXIL CROSSBAR <=> PLIC
axi_lite_if s_axi_lite_plic();
// AXIL CROSSBAR <=> CLINT
axi_lite_if s_axi_lite_clint();

//=======================
// HOLY CORE (2x MASTER)
//=======================

/* verilator lint_off PINMISSING */
holy_core core(
    .clk(clk), 
    .rst_n(rst_n),

    // Note : the AXI MASTER interface
    // is only used to retrieve instructions
    // in this tb. so it is a striahgt passthrough
    // to the top IF
    .m_axi(m_axi),

    // Note : The AXI LITE MASTER interface
    // goes to the corssbar as it can trasact with
    // multiple savles acrosse the system.
    // i.e. RAM, CLINT & PLIC.
    .m_axi_lite(m_axi_lite)

    // We don't use debug signals in tb
    // ...
);
/* verilator lint_on PINMISSING */

//==============================
// INTERFACE COMB ASSIGNEMENTS
//==============================

// Wires declarations
// (to slaves)
logic [SLV_NB            -1:0]  s_awvalid;
logic [SLV_NB            -1:0]  s_awready;
logic [SLV_NB*32     -1:0]      s_awch;
logic [SLV_NB            -1:0]  s_wvalid;
logic [SLV_NB            -1:0]  s_wready;
logic [SLV_NB            -1:0]  s_wlast;
logic [SLV_NB*32      -1:0]     s_wch;
logic [SLV_NB            -1:0]  s_bvalid;
logic [SLV_NB            -1:0]  s_bready;
logic [SLV_NB*2       -1:0]     s_bch;
logic [SLV_NB            -1:0]  s_arvalid;
logic [SLV_NB            -1:0]  s_arready;
logic [SLV_NB*32     -1:0]      s_arch;
logic [SLV_NB            -1:0]  s_rvalid;
logic [SLV_NB            -1:0]  s_rready;
logic [SLV_NB            -1:0]  s_rlast;
logic [SLV_NB*32      -1:0]     s_rch;

// ---------------------
// Slave assignements

// ALL SLVS ASSIGNS
always_comb begin
    m_axi_lite_wstrb = m_axi_lite.wstrb;
    s_axi_lite_plic.wstrb = m_axi_lite.wstrb;
    s_axi_lite_clint.wstrb = m_axi_lite.wstrb;
end

// SLV 0 : AXIL CB <=> COCOTB RAM
localparam SLV0_ID = 0;
always_comb begin
    m_axi_lite_awaddr = s_awch[SLV0_ID*32+31:SLV0_ID*32];
    m_axi_lite_awvalid = s_awvalid[SLV0_ID];
    s_awready[SLV0_ID] = m_axi_lite_awready;

    m_axi_lite_wdata = s_wch[SLV0_ID*32+31:SLV0_ID*32];
    m_axi_lite_wvalid = s_wvalid[SLV0_ID];
    m_axi_lite_wstrb = m_axi_lite.wstrb;
    s_wready[SLV0_ID] = m_axi_lite_wready;

    s_bch[SLV0_ID*2+1:SLV0_ID*2] = m_axi_lite_bresp;
    s_bvalid[SLV0_ID] = m_axi_lite_bvalid;
    m_axi_lite_bready = s_bready[SLV0_ID];

    m_axi_lite_araddr = s_arch[SLV0_ID*32+31:SLV0_ID*32];
    m_axi_lite_arvalid = s_arvalid[SLV0_ID];
    s_arready[SLV0_ID] = m_axi_lite_arready;

    s_rch[SLV0_ID*32+31:SLV0_ID*32] = m_axi_lite_rdata;
    s_rvalid[SLV0_ID] = m_axi_lite_rvalid;
    m_axi_lite_rready = s_rready[SLV0_ID];
end

// SLV 1 : AXIL CB <=> CLINT
localparam SLV1_ID = 1;
always_comb begin
    s_axi_lite_clint.awaddr = s_awch[SLV1_ID*32+31:SLV1_ID*32];
    s_axi_lite_clint.awvalid = s_awvalid[SLV1_ID];
    s_awready[SLV1_ID] = s_axi_lite_clint.awready;

    s_axi_lite_clint.wdata = s_wch[SLV1_ID*32+31:SLV1_ID*32];
    s_axi_lite_clint.wvalid = s_wvalid[SLV1_ID];
    s_axi_lite_clint.wstrb = m_axi_lite.wstrb;
    s_wready[SLV1_ID] = s_axi_lite_clint.wready;

    s_bch[SLV1_ID*2+1:SLV1_ID*2] = s_axi_lite_clint.bresp;
    s_bvalid[SLV1_ID] = s_axi_lite_clint.bvalid;
    s_axi_lite_clint.bready = s_bready[SLV1_ID];

    s_axi_lite_clint.araddr = s_arch[SLV1_ID*32+31:SLV1_ID*32];
    s_axi_lite_clint.arvalid = s_arvalid[SLV1_ID];
    s_arready[SLV1_ID] = s_axi_lite_clint.arready;

    s_rch[SLV1_ID*32+31:SLV1_ID*32] = s_axi_lite_clint.rdata;
    s_rvalid[SLV1_ID] = s_axi_lite_clint.rvalid;
    s_axi_lite_clint.rready = s_rready[SLV1_ID];
end

// SLV 2 : AXIL CB <=> PLIC
localparam SLV2_ID = 2;
always_comb begin
    s_axi_lite_plic.awaddr = s_awch[SLV2_ID*32+31:SLV2_ID*32];
    s_axi_lite_plic.awvalid = s_awvalid[SLV2_ID];
    s_awready[SLV2_ID] = s_axi_lite_plic.awready;

    s_axi_lite_plic.wdata = s_wch[SLV2_ID*32+31:SLV2_ID*32];
    s_axi_lite_plic.wvalid = s_wvalid[SLV2_ID];
    s_axi_lite_plic.wstrb = m_axi_lite.wstrb;
    s_wready[SLV2_ID] = s_axi_lite_plic.wready;

    s_bch[SLV2_ID*2+1:SLV2_ID*2] = s_axi_lite_plic.bresp;
    s_bvalid[SLV2_ID] = s_axi_lite_plic.bvalid;
    s_axi_lite_plic.bready = s_bready[SLV2_ID];

    s_axi_lite_plic.araddr = s_arch[SLV2_ID*32+31:SLV2_ID*32];
    s_axi_lite_plic.arvalid = s_arvalid[SLV2_ID];
    s_arready[SLV2_ID] = s_axi_lite_plic.arready;

    s_rch[SLV2_ID*32+31:SLV2_ID*32] = s_axi_lite_plic.rdata;
    s_rvalid[SLV2_ID] = s_axi_lite_plic.rvalid;
    s_axi_lite_plic.rready = s_rready[SLV2_ID];
end

//=======================
// AXI LITE XBAR
//=======================

// Cofig docs
// https://github.com/pulp-platform/axi/blob/master/doc/axi_lite_xbar.md

xbar_cfg_t Cfg;

initial begin
    Cfg.NoSlvPorts        = 3;
    Cfg.NoMstPorts        = 1;
    Cfg.MaxMstTrans       = 8;
    Cfg.MaxSlvTrans       = 8;
    Cfg.FallThrough       = 1'b0;
    Cfg.LatencyMode       = 10'b0;
    Cfg.PipelineStages    = 2;
    Cfg.AxiIdWidthSlvPorts = '0;
    Cfg.AxiIdUsedSlvPorts  = '0;
    Cfg.UniqueIds         = 1'b0;
    Cfg.AxiAddrWidth      = 32;
    Cfg.AxiDataWidth      = 32;
    Cfg.NoAddrRules       = 1;
end

// defined in vendor/axi/src/axi_pkg.sv
axi_pkg::xbar_rule_32_t [2:0] addr_map;

// EXTERNAL RAM
assign addr_map[0].id = 0;
assign addr_map[0].start_addr = 32'h0000;
assign addr_map[0].end_addr = 32'h2FFF;

// CLINT
assign addr_map[1].id = 1;
assign addr_map[1].start_addr = 32'h3000;
assign addr_map[1].end_addr = 32'hEFFF;

// PLIC
assign addr_map[2].id = 2;
assign addr_map[2].start_addr = 32'hF000;
assign addr_map[2].end_addr = 32'hFFFF;


axi_lite_xbar_intf #(
    Cfg,
    axi_pkg::xbar_rule_32_t
) crossbar (
    .clk_i(clk),
    .rst_ni(rst_n),
    .test_i(1'b0),
    .slv_ports('0),
    .mst_ports('0),
    .addr_map_i(addr_map),
    .en_default_mst_port_i(3'b000),
    .default_mst_port_i('0)
);

//=======================
// HOLY PLIC (LITE SLAVE)
//=======================

holy_plic #(
    NUM_IRQS
) plic (
    .clk        (clk),
    .rst_n      (rst_n),
    .irq_in     (irq_in),
    .s_axi_lite (s_axi_lite_plic),
    .ext_irq_o  (ext_irq_o)
);

//=========================
// HOLY CLINT (LITE SLAVE)
//=========================

holy_clint clint (
    .clk        (clk),
    .rst_n      (rst_n),
    .s_axi_lite (s_axi_lite_clint),
    .timer_irq  (timer_irq_o),
    .soft_irq   (soft_irq_o)
);

//===================================
// AXI FULL HOLY CORE <=> COCOTB RAM
//===================================

// Note : the AXI interface
// is only used to retrieve instructions
// in this tb. so it is a striahgt passthrough
// to the top IF.

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