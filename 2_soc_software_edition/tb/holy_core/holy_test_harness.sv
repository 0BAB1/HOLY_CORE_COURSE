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
localparam MST_NB = 1;

//=========================
// INTERFACES DECLARATIONS
//=========================

// HOLY CORE AXI FULL <=> EXTERNAL RAM
axi_if m_axi();
// HOLYCORE <=> AXIL CROSSBAR
axi_lite_if m_axi_lite();
AXI_LITE #(32,32) m_axi_lite_xbar_in [MST_NB-1:0] ();
AXI_LITE #(32,32) m_axi_lite_xbar_out [SLV_NB-1:0] ();
// AXIL CROSSBAR <=> PLIC
axi_lite_if axi_lite_plic();
// AXIL CROSSBAR <=> CLINT
axi_lite_if axi_lite_clint();

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
    .m_axi_lite(m_axi_lite),

    // Interrupts
    .timer_itr(timer_irq),
    .soft_itr(soft_irq),
    .ext_itr(ext_irq)

    // We don't use debug signals in tb
    // ...
);
/* verilator lint_on PINMISSING */

// convert axil intf to pulp's for axil xbar
hc_axil_pulp_axil_passthrough hc_to_xbar(
    .in_if(m_axi_lite),
    .out_if(m_axi_lite_xbar_in[0])
);

//=======================
// AXI LITE XBAR
//=======================

// Cofig docs
// https://github.com/pulp-platform/axi/blob/master/doc/axi_lite_xbar.md

localparam xbar_cfg_t Cfg = '{
    NoSlvPorts: MST_NB, // HC MST -> XBAR SLV
    NoMstPorts: SLV_NB, // XBAR MST -> SOC SLV
    MaxMstTrans: 8,
    MaxSlvTrans: 8,
    FallThrough: 1'b0,
    LatencyMode: 10'b0,
    PipelineStages: 2,
    AxiIdWidthSlvPorts: '0,
    AxiIdUsedSlvPorts: '0,
    UniqueIds: 1'b0,
    AxiAddrWidth: 32,
    AxiDataWidth: 32,
    NoAddrRules: 3
};

// defined in vendor/axi/src/axi_pkg.sv
axi_pkg::xbar_rule_32_t [2:0] addr_map;

// EXTERNAL RAM
assign addr_map[0].idx = 0;
assign addr_map[0].start_addr = 32'h0000;
assign addr_map[0].end_addr = 32'h2FFF;

// CLINT
assign addr_map[1].idx = 1;
assign addr_map[1].start_addr = 32'h3000;
assign addr_map[1].end_addr = 32'hEFFF;

// PLIC
assign addr_map[2].idx = 2;
assign addr_map[2].start_addr = 32'hF000;
assign addr_map[2].end_addr = 32'hFFFF;

axi_lite_xbar_intf #(
    .Cfg(Cfg),
    .rule_t(axi_pkg::xbar_rule_32_t)
) crossbar (
    .clk_i(clk),
    .rst_ni(rst_n),
    .test_i(1'b0),
    .slv_ports(m_axi_lite_xbar_in),
    .mst_ports(m_axi_lite_xbar_out),
    .addr_map_i(addr_map),
    .en_default_mst_port_i(3'b111),
    .default_mst_port_i('{1})
);

//=======================
// HOLY PLIC (LITE SLAVE)
//=======================

logic ext_irq;

holy_plic #(
    NUM_IRQS
) plic (
    .clk        (clk),
    .rst_n      (rst_n),
    .irq_in     (irq_in),
    .s_axi_lite (axi_lite_plic),
    .ext_irq_o  (ext_irq)
);

pulp_axil_hc_axil_passthrough plic_conv(
    .in_if(m_axi_lite_xbar_out[2]),
    .out_if(axi_lite_plic)
);

//=========================
// HOLY CLINT (LITE SLAVE)
//=========================

logic timer_irq;
logic soft_irq;

holy_clint #(
    .BASE_ADDR('h3000)
) clint (
    .clk        (clk),
    .rst_n      (rst_n),
    .s_axi_lite (axi_lite_clint),
    .timer_irq  (timer_irq),
    .soft_irq   (soft_irq)
);

pulp_axil_hc_axil_passthrough clint_conv(
    .in_if(m_axi_lite_xbar_out[1]),
    .out_if(axi_lite_clint)
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

//==============================================
// AXI LITE XBAR OUT <=> COCOTB EXTERNAL RAM
//=============================================

assign m_axi_lite_awaddr = m_axi_lite_xbar_out[0].aw_addr;
// AW channel
assign m_axi_lite_awaddr = m_axi_lite_xbar_out[0].aw_addr;
assign m_axi_lite_awvalid = m_axi_lite_xbar_out[0].aw_valid;
assign m_axi_lite_xbar_out[0].aw_ready = m_axi_lite_awready;

// W channel
assign m_axi_lite_wdata = m_axi_lite_xbar_out[0].w_data;
assign m_axi_lite_wstrb = m_axi_lite_xbar_out[0].w_strb;
assign m_axi_lite_wvalid = m_axi_lite_xbar_out[0].w_valid;
assign m_axi_lite_xbar_out[0].w_ready = m_axi_lite_wready;

// B channel
assign m_axi_lite_xbar_out[0].b_resp = m_axi_lite_bresp;
assign m_axi_lite_xbar_out[0].b_valid = m_axi_lite_bvalid;
assign m_axi_lite_bready = m_axi_lite_xbar_out[0].b_ready;

// AR channel
assign m_axi_lite_araddr = m_axi_lite_xbar_out[0].ar_addr;
assign m_axi_lite_arvalid = m_axi_lite_xbar_out[0].ar_valid;
assign m_axi_lite_xbar_out[0].ar_ready = m_axi_lite_arready;

// R channel
assign m_axi_lite_xbar_out[0].r_data = m_axi_lite_rdata;
assign m_axi_lite_xbar_out[0].r_resp = m_axi_lite_rresp;
assign m_axi_lite_xbar_out[0].r_valid = m_axi_lite_rvalid;
assign m_axi_lite_rready = m_axi_lite_xbar_out[0].r_ready;

endmodule