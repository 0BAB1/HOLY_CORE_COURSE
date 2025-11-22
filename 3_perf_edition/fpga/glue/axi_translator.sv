/* AXI_TRANSLATOR
*
* BRH 06/25
*
* This wrapper module instantiates the cache and routes the AXI interface
* as discrete Verilog signals for cocotb extensions.
*
* Note: this version only has AXI LITE
*/


module axi_translator (
    // Cpu Clock and Reset
    input  logic                     clk,
    input  logic                     rst_n,

    // Axi Clock
    input  logic                     aclk,

    // ==========
    // AXI LITE
    // ==========

    // AXI-Lite Write Address Channel
    output logic [31:0]              axi_lite_awaddr,
    output logic                     axi_lite_awvalid,
    input  logic                     axi_lite_awready,

    // AXI-Lite Write Data Channel
    output logic [31:0]              axi_lite_wdata,
    output logic [3:0]               axi_lite_wstrb,
    output logic                     axi_lite_wvalid,
    input  logic                     axi_lite_wready,

    // AXI-Lite Write Response Channel
    input  logic [1:0]               axi_lite_bresp,
    input  logic                     axi_lite_bvalid,
    output logic                     axi_lite_bready,

    // AXI-Lite Read Address Channel
    output logic [31:0]              axi_lite_araddr,
    output logic                     axi_lite_arvalid,
    input  logic                     axi_lite_arready,

    // AXI-Lite Read Data Channel
    input  logic [31:0]              axi_lite_rdata,
    input  logic [1:0]               axi_lite_rresp,
    input  logic                     axi_lite_rvalid,
    output logic                     axi_lite_rready,

    // ==========
    // CPU Interface
    // ==========
    input logic req_i,
    input logic [31:0] add_i,
    input logic we_i,
    input logic [31:0] wdata_i,
    input logic [3:0] be_i,
    output logic gnt_o,
    output logic r_valid_o,
    output logic [31:0] r_rdata_o
);

    import holy_core_pkg::*;

    // ==========
    // AXI LITE
    // ==========

    // Declare AXI Lite interface
    axi_lite_if axi_lite_master_intf();

    // Clock and Reset
    assign axi_lite_master_intf.aclk    = clk;
    assign axi_lite_master_intf.aresetn = rst_n;

    // Write Address Channel
    assign axi_lite_awaddr  = axi_lite_master_intf.awaddr;
    assign axi_lite_awvalid = axi_lite_master_intf.awvalid;
    assign axi_lite_master_intf.awready = axi_lite_awready;

    // Write Data Channel
    assign axi_lite_wdata  = axi_lite_master_intf.wdata;
    assign axi_lite_wstrb  = axi_lite_master_intf.wstrb;
    assign axi_lite_wvalid = axi_lite_master_intf.wvalid;
    assign axi_lite_master_intf.wready = axi_lite_wready;

    // Write Response Channel
    assign axi_lite_master_intf.bresp  = axi_lite_bresp;
    assign axi_lite_master_intf.bvalid = axi_lite_bvalid;
    assign axi_lite_bready             = axi_lite_master_intf.bready;

    // Read Address Channel
    assign axi_lite_araddr  = axi_lite_master_intf.araddr;
    assign axi_lite_arvalid = axi_lite_master_intf.arvalid;
    assign axi_lite_master_intf.arready = axi_lite_arready;

    // Read Data Channel
    assign axi_lite_master_intf.rdata  = axi_lite_rdata;
    assign axi_lite_master_intf.rresp  = axi_lite_rresp;
    assign axi_lite_master_intf.rvalid = axi_lite_rvalid;
    assign axi_lite_rready             = axi_lite_master_intf.rready;

    // dummy wireto shut verilator down
    cache_state_t cache_state;

    // Instantiate the cache module
    /* verilator lint_off PINMISSING */
    dm_top_to_axi_lite dm_top_to_axi_lite_glue(
    // CPU LOGIC CLOCK & RESET
    .clk(clk),
    .aclk(aclk),
    .rst_n(rst_n),

    // dm_top Interface
    .req_i(req_i),
    .add_i(add_i),
    .we_i(we_i),
    .wdata_i(wdata_i),
    .be_i(be_i),
    .gnt_o(gnt_o),
    .r_valid_o(r_valid_o),
    .r_rdata_o(r_rdata_o),

    // AXI LITE Interface for external requests
    .out_if_axil_m(axi_lite_master_intf)
);
    /* verilator lint_on PINMISSING */

endmodule
