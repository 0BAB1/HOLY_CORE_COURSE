/**
 *   HOLY_PLIC_AXI_LITE
 *
 *   Description : Plain Verilog wrapper for the Holy Core PLIC.
 *                 Uses no SystemVerilog features.
 *                 Direct routing of AXI-Lite signals and IRQs.
 */

module holy_plic_top #(
    parameter NUM_IRQS  = 5,
    parameter BASE_ADDR = 32'h0000_0000
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Async IRQ inputs
    input  wire [NUM_IRQS-1:0]    irq_in,

    // AXI-Lite slave interface
    input  wire [31:0]            s_axi_awaddr,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,
    input  wire [31:0]            s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,
    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [31:0]            s_axi_araddr,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,
    output wire [31:0]            s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // IRQ output to CPU
    output wire                   ext_irq_o,

    // debug
    output wire [NUM_IRQS-1:0]  irq_meta,
    output wire [NUM_IRQS-1:0]  irq_req,
    output wire [NUM_IRQS-1:0]  ip,
    output wire in_service
);

    // Internal reg/wire bundling to match axi_lite_if manually
    // Since holy_plic now uses individual signals instead of interface

    // Instantiate stripped-down holy_plic
    // Internal wires to connect to debug outputs
    wire [NUM_IRQS-1:0] irq_meta_int;
    wire [NUM_IRQS-1:0] irq_req_int;
    wire [NUM_IRQS-1:0] ip_int;
    wire in_service_int;

    // Connect debug outputs to wrapper instance
    holy_plic_wrapper #(
        .NUM_IRQS(NUM_IRQS),
        .BASE_ADDR(BASE_ADDR)
    ) u_holy_plic_top (
        .clk(clk),
        .rst_n(rst_n),
        .irq_in(irq_in),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .ext_irq_o(ext_irq_o),

        .irq_meta(irq_meta_int),
        .irq_req(irq_req_int),
        .ip(ip_int),
        .in_service(in_service_int)
    );

    // Drive outputs
    assign irq_meta    = irq_meta_int;
    assign irq_req     = irq_req_int;
    assign ip          = ip_int;
    assign in_service  = in_service_int;

endmodule
