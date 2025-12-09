/** Simple Platform Level Interrupt Controller
*
*   Author : BRH
*   Project : Holy Core SoC & Software edition
*   Description : A PLIC for the HOLY CORE target. works around AXI-LITE.
*                 and supports async interrupts. Runs on a single clk (axi clock).
*                 meaning output interrupt request is synced to the AXI clock.
*                 in HOLY CORE its okay as there is a single clock domain for
*                 the whole SoC.
*                 Sync reset.
*                 Supports non level interrupts (latches until claimed !)
*
*   Created 07/25
*/

// todo : add AXI error on wong address for write request
// instead of a simple tb display (B channel resp)

import holy_core_pkg::*;

module holy_plic #(
    parameter NUM_IRQS = 5,
    parameter BASE_ADDR = 0
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Async interrupt in
    input  logic [NUM_IRQS-1:0]  irq_in,

    // AXI Lite slave interface (simplified)
    axi_lite_if.slave s_axi_lite,

    // Interrupt output to core
    output logic                 ext_irq_o
);

    // REGISTERS MAP
    localparam ENABLE = 32'd0;
    localparam CONTEXT_CLAIM_COMPLETE = 32'd4;

    /**
    *   GATEWAYS
    */

    // The role of this gateway is to sync interrupt signals
    // and set the pending signals accordingly.
    logic [NUM_IRQS-1:0]  ip; //Interrupt Pending...
    logic [NUM_IRQS-1:0]  irq_meta;
    logic [NUM_IRQS-1:0]  irq_req;
    logic [NUM_IRQS-1:0]  irq_clear;

    // Synchronise the incomming interupts
    // (comming from different clock domain
    // probably slower e.g. I2C, SPI, etc...)
    // Synchronize and latch incoming interrupts
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            for (int i = 0; i < NUM_IRQS; i++) begin
                irq_meta[i] <= 1'b0;
                irq_req[i]  <= 1'b0;
            end
        end else begin
            for (int i = 0; i < NUM_IRQS; i++) begin
                // Two-flop synchronizer for irq_in
                irq_meta[i] <= irq_in[i];
                
                // Latch the request if seen, until cleared
                if (irq_clear[i])
                    irq_req[i] <= 1'b0;
                else if (irq_meta[i])
                    irq_req[i] <= 1'b1;
            end
        end
    end

    always_comb begin : generate_pending
        for(int i = 0; i < NUM_IRQS; i++)begin
            ip[i] = irq_req[i] & enabled[i];
        end
    end

    /**
    *   CONTROLLER STATE MACHINE
    */

    // Controller's in service state
    // This signal shows an interrupt is being serviced
    // which deasserts target's notification until completion.
    // even though the actual interrput pending signal commin
    // from the gateways is high.
    logic in_service, in_service_next;
    // We also have to remember what is the current ID
    // being serviced. This is because the targets rewrites
    // this ID to the CONTEXT_CLAIM_COMPLETE register
    // once handling is complete. This completion write
    // deassets in_service and allows the output notification
    // to be high again
    logic [$clog2(NUM_IRQS):0] serviced_id, serviced_id_next;
    // Note that service id is set on claim. As the target can
    // manually, without notification claim another interrupt
    // before declaring completion of the first one.
    // This is used in some handler to check if we can handle
    // another eventual interrupt before doign a costly
    // context switch.

    // Axi lite states
    axi_state_slave_t state, next_state;
    logic [31:0] awaddr, awaddr_next;
    logic [31:0] araddr, araddr_next;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            in_service <= 1'b0;
            state <= SLAVE_IDLE;
            awaddr <= 0;
            araddr <= 0;
            serviced_id <= 0;
        end else begin
            in_service <= in_service_next;
            state <= next_state;
            awaddr <= awaddr_next;
            araddr <= araddr_next;
            serviced_id <= serviced_id_next;
        end
    end

    always_comb begin : axi_lite_fsm
        // stats & registers
        in_service_next = in_service;
        next_state = state;
        awaddr_next = awaddr;
        araddr_next = araddr;
        enabled_next = enabled;
        serviced_id_next = serviced_id;
        for (int i = 0; i < NUM_IRQS; i++) begin
            irq_clear[i] = 1'b0;
        end

        // AXI LITE DEFAULT
        s_axi_lite.awready = 1'b0;
        s_axi_lite.wready = 1'b0;
        s_axi_lite.bresp = 2'b00;
        s_axi_lite.bvalid = 1'b0;
        s_axi_lite.arready = 1'b0;
        s_axi_lite.rdata = 32'd0;
        s_axi_lite.rvalid = 1'b0;
        s_axi_lite.rresp = 2'b00;

        case (state)
            SLAVE_IDLE: begin
                s_axi_lite.awready = 1'b1;
                s_axi_lite.arready = 1'b1;

                if(s_axi_lite.arvalid)begin
                    next_state = LITE_SENDING_READ_DATA;
                    araddr_next = s_axi_lite.araddr - BASE_ADDR;
                end

                if(s_axi_lite.awvalid)begin
                    next_state = LITE_RECEIVING_WRITE_DATA;
                    awaddr_next = s_axi_lite.awaddr - BASE_ADDR;
                end
            end

            LITE_SENDING_READ_DATA: begin
                s_axi_lite.rvalid = 1'b1;

                // Set rdata
                case(araddr)
                    ENABLE:begin
                        s_axi_lite.rresp = 2'b00;
                        // simply return 0 extended contents
                        s_axi_lite.rdata = { {(32-NUM_IRQS){1'b0}}, enabled };
                    end

                    CONTEXT_CLAIM_COMPLETE: begin
                        s_axi_lite.rresp = 2'b00;

                        if(max_id != '0)begin
                            in_service_next = 1'b1;
                            serviced_id_next = max_id;
                            s_axi_lite.rdata = 32'(max_id);
                        end else begin
                            // No interrupt pending.
                            // We aslso clear to avoid deadlocks
                            for (int i = 0; i < NUM_IRQS; i++) begin
                                irq_clear[i] = 1'b1;
                            end
                            in_service_next = 1'b0;
                            s_axi_lite.rdata = 32'd0;
                        end
                    end

                    default: begin
                        // Return error
                        s_axi_lite.rresp = 2'b11;
                        s_axi_lite.rdata = 32'hAEAEAEAE;
                    end
                endcase

                if(s_axi_lite.rready)begin
                    next_state = SLAVE_IDLE;
                end
            end

            LITE_RECEIVING_WRITE_DATA: begin
                s_axi_lite.wready = 1'b1;
                // todo : add wstrb masking

                if(s_axi_lite.wvalid)begin
                    // Get wdata
                    case(awaddr)
                        ENABLE:begin
                            enabled_next = s_axi_lite.wdata[NUM_IRQS-1:0];
                        end

                        CONTEXT_CLAIM_COMPLETE:begin
                            if(s_axi_lite.wdata == 32'(serviced_id))begin
                                in_service_next = 0;
                                irq_clear[serviced_id - 1] = 1;
                            end
                        end

                        default: $display("PLIC: not a valid address pal!");
                    endcase

                    next_state =  LITE_SENDING_WRITE_RES;
                end
            end

            LITE_SENDING_WRITE_RES:begin
                s_axi_lite.bresp = 2'b00;
                s_axi_lite.bvalid = 1'b1;

                if(s_axi_lite.bready)begin
                    next_state = SLAVE_IDLE;
                end
            end

            default : begin
                $display("STATE ERROR");
            end
        endcase
    end

    /**
    *   ACTUAL CONTROLLER LOGIC
    */

    // Logic cells => Determine the max id
    // Based on this scheme:
    // https://people.eecs.berkeley.edu/~krste/papers/riscv-privileged-v1.9.pdf#page=74
    logic [$clog2(NUM_IRQS):0] max_id;
    logic found;

    always_comb begin : determine_max_id
        max_id = 0;
        found = 0;

        for (int i = NUM_IRQS - 1; i >= 0; i--) begin
            if (!found && ip[i]) begin
                max_id = ($clog2(NUM_IRQS)+1)'(i + 1);
                found = 1;
            end
        end
    end


    // Registers for enable and pending interrupts
    logic [NUM_IRQS-1:0] enabled, enabled_next;
    // logic [NUM_IRQS-1:0] enabled_next;

    always_comb begin : set_target_notification
        ext_irq_o = |ip && ~in_service;
    end

    always_ff @(posedge clk) begin : enabled_register
        if(~rst_n) begin
            enabled <= {NUM_IRQS{1'b1}};
        end
        else begin
            enabled <= enabled_next;
        end
    end
endmodule
