/* AXI_TRANSLATOR
*
* BRH 11/24
*
* This wrapper module instantiates the instruction cache and routes the AXI interface 
* as discrete Verilog signals for cocotb.
* Adapted for read-only instruction cache.
*/

import holy_core_pkg::*;

module axi_translator #(
    parameter WORDS_PER_LINE = 8,
    parameter NUM_SETS = 8,
    parameter NUM_WAYS = 2
)(
    // ==========
    // Clock and Reset
    // ==========
    input  logic                     clk,
    input  logic                     rst_n,

    // ==========
    // AXI FULL (Read-only for instruction cache)
    // ==========

    // Write Address Channel (directly noncacheable writes)
    output logic [3:0]               axi_awid,
    output logic [31:0]              axi_awaddr,
    output logic [7:0]               axi_awlen,
    output logic [2:0]               axi_awsize,
    output logic [1:0]               axi_awburst,
    output logic                     axi_awvalid,
    input  logic                     axi_awready,

    // Write Data Channel (unused)
    output logic [31:0]              axi_wdata, 
    output logic [3:0]               axi_wstrb,
    output logic                     axi_wlast,
    output logic                     axi_wvalid,
    input  logic                     axi_wready,

    // Write Response Channel (unused)
    input  logic [3:0]               axi_bid,
    input  logic [1:0]               axi_bresp,
    input  logic                     axi_bvalid,
    output logic                     axi_bready,

    // Read Address Channel
    output logic [3:0]               axi_arid,
    output logic [31:0]              axi_araddr,
    output logic [7:0]               axi_arlen,
    output logic [2:0]               axi_arsize,
    output logic [1:0]               axi_arburst,
    output logic                     axi_arvalid,
    input  logic                     axi_arready,

    // Read Data Channel
    input  logic [3:0]               axi_rid,
    input  logic [31:0]              axi_rdata,
    input  logic [1:0]               axi_rresp,
    input  logic                     axi_rlast,
    input  logic                     axi_rvalid,
    output logic                     axi_rready,

    // ==========
    // CPU Interface (Read-only)
    // ==========
    input  logic [31:0]              cpu_address,
    output logic [31:0]              cpu_read_data,
    input  logic                     cpu_req_valid,
    output logic                     cpu_req_ready,
    output logic                     cpu_read_valid,
    input  logic                     cpu_read_ack
);

    // ==========
    // AXI FULL Interface
    // ==========

    axi_if axi_master_intf();

    // Write Address Channel
    assign axi_awid                    = axi_master_intf.awid;
    assign axi_awaddr                  = axi_master_intf.awaddr;
    assign axi_awlen                   = axi_master_intf.awlen;
    assign axi_awsize                  = axi_master_intf.awsize;
    assign axi_awburst                 = axi_master_intf.awburst;
    assign axi_awvalid                 = axi_master_intf.awvalid;
    assign axi_master_intf.awready     = axi_awready;

    // Write Data Channel
    assign axi_wdata                   = axi_master_intf.wdata;
    assign axi_wstrb                   = axi_master_intf.wstrb;
    assign axi_wlast                   = axi_master_intf.wlast;
    assign axi_wvalid                  = axi_master_intf.wvalid;
    assign axi_master_intf.wready      = axi_wready;

    // Write Response Channel
    assign axi_master_intf.bid         = axi_bid;
    assign axi_master_intf.bresp       = axi_bresp;
    assign axi_master_intf.bvalid      = axi_bvalid;
    assign axi_bready                  = axi_master_intf.bready;

    // Read Address Channel
    assign axi_arid                    = axi_master_intf.arid;
    assign axi_araddr                  = axi_master_intf.araddr;
    assign axi_arlen                   = axi_master_intf.arlen;
    assign axi_arsize                  = axi_master_intf.arsize;
    assign axi_arburst                 = axi_master_intf.arburst;
    assign axi_arvalid                 = axi_master_intf.arvalid;
    assign axi_master_intf.arready     = axi_arready;

    // Read Data Channel
    assign axi_master_intf.rid         = axi_rid;
    assign axi_master_intf.rdata       = axi_rdata;
    assign axi_master_intf.rresp       = axi_rresp;
    assign axi_master_intf.rlast       = axi_rlast;
    assign axi_master_intf.rvalid      = axi_rvalid;
    assign axi_rready                  = axi_master_intf.rready;

    // ==========
    // Cache State (debug)
    // ==========
    cache_state_t cache_state;

    // ==========
    // Instantiate the instruction cache
    // ==========
    holy_instr_cache #(
        .WORDS_PER_LINE(WORDS_PER_LINE),
        .NUM_SETS(NUM_SETS),
        .NUM_WAYS(NUM_WAYS)
    ) cache_system (
        .clk(clk), 
        .rst_n(rst_n),

        // CPU Interface
        .address(cpu_address),
        .read_data(cpu_read_data),
        .req_valid(cpu_req_valid),
        .req_ready(cpu_req_ready),
        .read_valid(cpu_read_valid),
        .read_ack(cpu_read_ack),

        // AXI Master Interface
        .axi(axi_master_intf),

        // State output
        .cache_state(cache_state)
    );

endmodule