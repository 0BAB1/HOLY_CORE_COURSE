module holy_plic #(
    parameter int NUM_IRQS = 5
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // External interrupt inputs (assumed synchronized)
    input  logic [NUM_IRQS-1:0]  irq_in,

    // AXI Lite slave interface (simplified)
    input  logic                 axi_awvalid,
    output logic                 axi_awready,
    input  logic [31:0]          axi_awaddr,

    input  logic                 axi_wvalid,
    output logic                 axi_wready,
    input  logic [31:0]          axi_wdata,

    output logic [31:0]          axi_rdata,
    input  logic                 axi_rvalid,
    output logic                 axi_rready,
    input  logic [31:0]          axi_araddr,
    input  logic                 axi_arvalid,
    output logic                 axi_arready,

    // Interrupt output to core
    output logic                 ext_irq_o
);

    // Registers for enable and pending interrupts
    logic [NUM_IRQS-1:0] enabled;
    logic [NUM_IRQS-1:0] pending;

    // AXI ready signals - always ready
    assign axi_awready = 1'b1;
    assign axi_wready  = 1'b1;
    assign axi_arready = 1'b1;
    assign axi_rready  = axi_rvalid;

    // Latch IRQ inputs into pending, handle writes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enabled <= '0;
            pending <= '0;
        end else begin
            // Latch new interrupts
            pending <= pending | irq_in;

            // Write access
            if (axi_awvalid && axi_wvalid) begin
                case (axi_awaddr[3:0])
                    4'h0: enabled <= axi_wdata[NUM_IRQS-1:0]; // ENABLE register
                    4'h4: begin
                        // CLAIM_COMPLETE register: clear pending bit of IRQ ID written
                        if ((axi_wdata[4:0] != 0) && (axi_wdata[4:0] <= NUM_IRQS)) begin
                            pending[axi_wdata[4:0] - 1] <= 1'b0;
                        end
                    end
                    default: /* no op */;
                endcase
            end
        end
    end

    // Read logic combinational
    always_comb begin
        case (axi_araddr[3:0])
            4'h0: axi_rdata = {{(32-NUM_IRQS){1'b0}}, enabled};
            4'h4: begin
                axi_rdata = 32'd0;
                // Return highest priority IRQ ID pending & enabled (ID=1 is highest priority)
                for (int i = NUM_IRQS-1; i >= 0; i--) begin
                    if (pending[i] && enabled[i]) begin
                        axi_rdata = i + 1; // IRQ ID 1-based
                    end
                end
            end
            default: axi_rdata = 32'd0;
        endcase
    end

    // Interrupt output signal - asserted if any enabled & pending IRQ
    always_comb begin
        ext_irq_o = 1'b0;
        for (int j = 0; j < NUM_IRQS; j++) begin
            if (pending[j] && enabled[j]) ext_irq_o = 1'b1;
        end
    end

endmodule
