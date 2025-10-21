/** holy_top
*
*   Author : BRH
*   Project : Holy re V2
*   Description : Top wrapper for holy core. May not be used as top in vivado or synth tool as this may require
*                 another OG VERILOG top wrapper.
*/

import axi_pkg::*;

module holy_top (
    // CPU clock and active low reset
    input logic clk,
    input logic rst_n,
    input logic periph_rst_n,

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

    // INTERRUPTS & EXTERNAL REQUESTS
    input logic [NUM_IRQS-1:0]  irq_in,

    // JTAG access to debug module
    input  logic        tck_i,
    input  logic        tms_i,
    input  logic        trst_ni,
    input  logic        td_i,
    output logic        td_o,

    // RAW DEBUG HINT SIGNALS FOR ILA
    output logic [31:0] pc,
    output logic [31:0] pc_next,
    output logic [31:0] instruction,
    output logic i_cache_stall,
    output logic [3:0] i_cache_state,
    output logic [3:0] i_cache_next_state,
    output logic d_cache_stall,

    // test debug stuff
    input logic tb_debug_req,

    // TMP : debugging
    output logic [31:0] debug_bus_add,
    output logic debug_bus_req
);

localparam NUM_IRQS = 2;

//=========================
// INTERFACES DECLARATIONS
//=========================

// HOLY CORE AXI FULL <=> EXTERNAL RAM
axi_if m_axi();
// HOLYCORE <=> AXIL CROSSBAR
axi_lite_if m_axi_lite();
AXI_LITE #(32,32) m_axi_lite_xbar_in [MST_NB-1:0] ();
AXI_LITE #(32,32) m_axi_lite_xbar_out [SLV_NB-1:0] ();
// AXIL CROSSBAR <=> BOOT ROM
axi_lite_if axi_lite_boot_rom();
// AXIL CROSSBAR <=> PLIC
axi_lite_if axi_lite_plic();
// AXIL CROSSBAR <=> CLINT
axi_lite_if axi_lite_clint();

//=======================
// HOLY CORE (2x MASTER)
//=======================

/* verilator lint_off PINMISSING */
holy_core #(
    .DCACHE_EN(0)
) core(
    // these are set in sim
    // by loading the adres in ASM
    // into t0 (x5) and t1 and by directly
    // setting it using cocotb
    // .DEBUG_HALT_ADDR(0),
    // .DEBUG_EXCEPTION_ADDR(0),

    .clk(clk), 
    .rst_n(rst_n),

    .debug_halt_addr(32'h30000800),
    .debug_exception_addr(32'h30000810),

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
    .ext_itr(ext_irq),
    .debug_req(core_debug_req),

    // DBUG SIGNALS
    .debug_pc(pc),
    .debug_pc_next(pc_next),
    .debug_instruction(instruction),
    .debug_i_cache_stall(i_cache_stall),
    .debug_d_cache_stall(d_cache_stall),
    .debug_i_cache_state(i_cache_state),
    .debug_i_next_cache_state(i_cache_next_state)
);
/* verilator lint_on PINMISSING */

logic core_debug_req;
assign core_debug_req = tb_debug_req || dm_debug_req;

// convert axil intf to pulp's for axil xbar
hc_axil_pulp_axil_passthrough hc_to_xbar(
    .in_if(m_axi_lite),
    .out_if(m_axi_lite_xbar_in[1])
);

//=======================
// AXI LITE XBAR
//=======================

// Cofig docs
// https://github.com/pulp-platform/axi/blob/master/doc/axi_lite_xbar.md

localparam SLV_NB = 5;
localparam MST_NB = 2;

localparam xbar_cfg_t Cfg = '{
    NoSlvPorts: MST_NB, // HC MST -> XBAR SLV
    NoMstPorts: SLV_NB, // XBAR MST -> SOC SLV
    MaxMstTrans: 1,
    MaxSlvTrans: 1,
    FallThrough: 1'b0,
    LatencyMode: 10'b0,
    PipelineStages: 0,
    AxiIdWidthSlvPorts: '0,
    AxiIdUsedSlvPorts: '0,
    UniqueIds: 1'b0,
    AxiAddrWidth: 32,
    AxiDataWidth: 32,
    NoAddrRules: 6
};

// defined in vendor/axi/src/axi_pkg.sv
axi_pkg::xbar_rule_32_t [Cfg.NoAddrRules-1:0] addr_map;

// BOOT ROM
assign addr_map[0].idx = 4;
assign addr_map[0].start_addr = 32'h0;
assign addr_map[0].end_addr = 32'h0FFFFFFF;

// EXTERNAL REQUESTS (peripherals)
assign addr_map[5].idx = 0;
assign addr_map[5].start_addr = 32'h10000000;
assign addr_map[5].end_addr = 32'h2FFFFFFF;

// DEBUG MODULE
assign addr_map[3].idx = 3;
assign addr_map[3].start_addr = 32'h30000000;
assign addr_map[3].end_addr = 32'h3FFFFFFF;

// CLINT
assign addr_map[1].idx = 1;
assign addr_map[1].start_addr = 32'h40000000;
assign addr_map[1].end_addr = 32'h7FFFFFFF;

// EXTERNAL REQUESTS (RAM)
assign addr_map[4].idx = 0;
assign addr_map[4].start_addr = 32'h80000000;
assign addr_map[4].end_addr = 32'h8FFFFFFF;

// PLIC
assign addr_map[2].idx = 2;
assign addr_map[2].start_addr = 32'h90000000;
assign addr_map[2].end_addr = 32'hFFFFFFFF;


axi_lite_xbar_intf #(
    .Cfg(Cfg),
    .rule_t(axi_pkg::xbar_rule_32_t)
) crossbar (
    .clk_i(clk),
    .rst_ni(periph_rst_n),
    .test_i(1'b0),
    .slv_ports(m_axi_lite_xbar_in),
    .mst_ports(m_axi_lite_xbar_out),
    .addr_map_i(addr_map),
    .en_default_mst_port_i(2'b11),
    .default_mst_port_i('{default: 2'b01})
);

//=======================
// HOLY BOOT ROM (LITE SLAVE)
//=======================

pulp_axil_hc_axil_passthrough boot_conv(
    .in_if(m_axi_lite_xbar_out[4]),
    .out_if(axi_lite_boot_rom)
);

holy_boot_rom #(
    .BASE_ADDR(0)
) boot_rom (
    .clk(clk),
    .rst_n(periph_rst_n),
    .axi(axi_lite_boot_rom)
);

//=======================
// HOLY PLIC (LITE SLAVE)
//=======================

logic ext_irq;

holy_plic #(
    .NUM_IRQS (NUM_IRQS),
    .BASE_ADDR('h90000000)
) plic (
    .clk        (clk),
    .rst_n      (periph_rst_n),
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
    .BASE_ADDR('h40000000)
) clint (
    .clk        (clk),
    .rst_n      (periph_rst_n),
    .s_axi_lite (axi_lite_clint),
    .timer_irq  (timer_irq),
    .soft_irq   (soft_irq)
);

pulp_axil_hc_axil_passthrough clint_conv(
    .in_if(m_axi_lite_xbar_out[1]),
    .out_if(axi_lite_clint)
);

// =========================
// DEBUG MODULE (LITE SLAVE)
// =========================

// core uses axi_lite but dm uses classical pulp's "mem" format
// so we need conversion layers
axi_lite_if debug_module_axi_lite();

// conv back to holy_core's axi lite interface definition
pulp_axil_hc_axil_passthrough axil_dm_conv_hc (
    .in_if(m_axi_lite_xbar_out[3]),
    .out_if(debug_module_axi_lite)
);

// use custom glue logic to talk with the debug module
axi_lite_to_dm_top #(
    .AXI_DATA_WIDTH(32)
) debug_axi_conv (
    .clk(clk),
    .rst_n(periph_rst_n),
    .s_axi_lite(debug_module_axi_lite),

    .device_req_o  (mem_req),
    .device_we_o   (mem_we),
    .device_addr_o (mem_addr),
    .device_be_o   (mem_strb),
    .device_wdata_o(mem_wdata),
    .device_rdata_i(mem_rdata)
);

logic mem_req;
logic mem_we;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [3:0] mem_strb;
logic [31:0] mem_rdata;
logic dm_debug_req;
logic mem_rvalid;
assign mem_rvalid = mem_req;

dm_top #(
    .NrHarts      (1) ,
    .IdcodeValue  ( 32'h0BA00477 )
) u_dm_top (
    .clk_i        (clk),
    .rst_ni       (periph_rst_n),
    .testmode_i   (1'b0),
    .ndmreset_o   (),
    .dmactive_o   (),
    .debug_req_o  (dm_debug_req),
    .unavailable_i(1'b0),

    // Bus device with debug memory (for execution-based debug).
    // .device_req_i  (dbg_device_req),
    // .device_we_i   (dbg_device_we),
    // .device_addr_i (dbg_device_addr),
    // .device_be_i   (dbg_device_be),
    // .device_wdata_i(dbg_device_wdata),
    // .device_rdata_o(dbg_device_rdata),
    .device_req_i  (mem_req),
    .device_we_i   (mem_we),
    .device_addr_i (mem_addr),
    .device_be_i   (mem_strb),
    .device_wdata_i(mem_wdata),
    .device_rdata_o(mem_rdata),

    // BUS ACCESS
    .host_req_o    (bus_req),
    .host_add_o    (bus_add),
    .host_we_o     (bus_we),
    .host_wdata_o  (bus_wdata),
    .host_be_o     (bus_be),
    .host_gnt_i    (bus_gnt),
    .host_r_valid_i(bus_rvalid),
    .host_r_rdata_i(bus_rdata),

    .tck_i(tck_i),
    .tms_i(tms_i),
    .trst_ni(trst_ni),
    .td_i(td_i),
    .td_o(td_o)
);

logic           bus_req;
logic [31:0]    bus_add;
assign debug_bus_req = bus_req;
assign debug_bus_add = bus_add;
logic           bus_we;
logic [31:0]    bus_wdata;
logic [3:0]     bus_be;
logic           bus_gnt;
logic           bus_rvalid;
logic [31:0]    bus_rdata;

dm_top_to_axi_lite dm_top_as_master_conv (
    // CPU LOGIC CLOCK & RESET
    .clk(clk),
    .rst_n(periph_rst_n),

    // dm_top Interface 
    .req_i(bus_req),
    .add_i(bus_add),
    .we_i(bus_we),
    .wdata_i(bus_wdata),
    .be_i(bus_be),
    .gnt_o(bus_gnt),
    .r_valid_o(bus_rvalid),
    .r_rdata_o(bus_rdata),

    // AXI LITE Interface for external requests
    .out_if_axil_m(axi_lite_dm_hc)
);

axi_lite_if axi_lite_dm_hc();

// convert this to pulp compliant interface
hc_axil_pulp_axil_passthrough dm_top_sba_axil_conv(
    .in_if(axi_lite_dm_hc),
    .out_if(m_axi_lite_xbar_in[0])
);

//===================================
// AXI FULL HOLY CORE <=> COCOTB RAM
//===================================

// Note : the AXI interface
// is only used to retrieve instructions
// in this tb. so it is a striahgt passthrough
// to the top IF.

// Connect the discrete AXI signals to the m_axi

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

//===================================
// AXI LITE XBAR OUT <=> EXTERNALS
//===================================

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

