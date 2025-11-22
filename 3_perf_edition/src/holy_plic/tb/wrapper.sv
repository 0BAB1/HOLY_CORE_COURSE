/** TB wrapper for the holy plic
*
*   Author : BRH
*   Project : Holy Core SoC & Software edition
*   Description : Exposes AXI Lite signals as discrete
*                 Wire for cocotbext-axi.
*
*   Created 07/25
*/

module holy_plic_wrapper #(
    parameter int NUM_IRQS = 5
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // Async interrupt in
    input  logic [NUM_IRQS-1:0]        irq_in,

    // AXI Lite slave signals
    input  logic [31:0]  s_axi_awaddr,
    input  logic                       s_axi_awvalid,
    output logic                       s_axi_awready,

    input  logic [31:0]  s_axi_wdata,
    input  logic [3:0] s_axi_wstrb,
    input  logic                       s_axi_wvalid,
    output logic                       s_axi_wready,

    output logic [1:0]                 s_axi_bresp,
    output logic                       s_axi_bvalid,
    input  logic                       s_axi_bready,

    input  logic [31:0]  s_axi_araddr,
    input  logic                       s_axi_arvalid,
    output logic                       s_axi_arready,

    output logic [31:0]  s_axi_rdata,
    output logic [1:0]                 s_axi_rresp,
    output logic                       s_axi_rvalid,
    input  logic                       s_axi_rready,

    // Interrupt output to core
    output logic                       ext_irq_o
);

    // Instantiate the AXI Lite interface
    axi_lite_if s_axi_lite();

    // Tie discrete signals to the interface
    assign s_axi_lite.awaddr  = s_axi_awaddr;
    assign s_axi_lite.awvalid = s_axi_awvalid;
    assign s_axi_awready      = s_axi_lite.awready;

    assign s_axi_lite.wdata   = s_axi_wdata;
    assign s_axi_lite.wstrb   = s_axi_wstrb;
    assign s_axi_lite.wvalid  = s_axi_wvalid;
    assign s_axi_wready       = s_axi_lite.wready;

    assign s_axi_bresp        = s_axi_lite.bresp;
    assign s_axi_bvalid       = s_axi_lite.bvalid;
    assign s_axi_lite.bready  = s_axi_bready;

    assign s_axi_lite.araddr  = s_axi_araddr;
    assign s_axi_lite.arvalid = s_axi_arvalid;
    assign s_axi_arready      = s_axi_lite.arready;

    assign s_axi_rdata        = s_axi_lite.rdata;
    assign s_axi_rresp        = s_axi_lite.rresp;
    assign s_axi_rvalid       = s_axi_lite.rvalid;
    assign s_axi_lite.rready  = s_axi_rready;

    /* verilator lint_off NULLPORT */
    /* verilator lint_off PINMISSING */

    // Instantiate the DUT
    holy_plic #(
        .NUM_IRQS(NUM_IRQS)
    ) u_holy_plic (
        .clk        (clk),
        .rst_n      (rst_n),
        .irq_in     (irq_in),
        .s_axi_lite (s_axi_lite),
        .ext_irq_o  (ext_irq_o)
    );

    /* verilator lint_on NULLPORT */
    /* verilator lint_off PINMISSING */

endmodule
