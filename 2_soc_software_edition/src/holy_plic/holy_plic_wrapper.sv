/**
*   HOLY_PLIC_WRAPPER
*
*   Author : BRH
*   Description : Wrapper module for the PLIC.
                  Just an AXI detailled interfacer                    
*/

module holy_plic_wrapper #(
    parameter NUM_IRQS   = 5,
    parameter BASE_ADDR  = 32'h0000_0000
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Async interrupt inputs
    input  wire [NUM_IRQS-1:0]   irq_in,

    // AXI Lite slave interface
    input  wire [31:0]           s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [31:0]           s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,

    input  wire [31:0]           s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    output wire [31:0]           s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    // Interrupt output to core
    output wire                  ext_irq_o,

    // debug
    output logic [NUM_IRQS-1:0]  irq_meta,
    output logic [NUM_IRQS-1:0]  irq_req,
    output logic [NUM_IRQS-1:0]  ip,
    output logic in_service,
    output logic [NUM_IRQS-1:0] enabled
);

    // AXI Lite interface bundle
    axi_lite_if s_axi_lite();

    // AXI Lite interface connections
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

    // Instantiate the PLIC
    holy_plic #(
        .NUM_IRQS(NUM_IRQS),
        .BASE_ADDR(BASE_ADDR)
    ) inst_holy_plic (
        .clk(clk),
        .rst_n(rst_n),
        .irq_in(irq_in),
        .s_axi_lite(s_axi_lite),
        .ext_irq_o(ext_irq_o),

        // debug
        .irq_meta,
        .irq_req,
        .ip,
        .in_service
    );

endmodule
