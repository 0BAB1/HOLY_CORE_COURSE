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
*
*   Created 07/25
*/

import holy_core_pkg::*;

module holy_plic #(
    parameter int NUM_IRQS = 5
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
    logic [NUM_IRQS-1:0] ip; //Interrupt Pending...
    logic [NUM_IRQS-1:0]  irq_meta;
    logic [NUM_IRQS-1:0]  irq_req;

    // Synchronise the incomming interupts
    // (coming from different clock domains)
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            for(int i = 0; i < NUM_IRQS; i++)begin
                irq_meta[i] <= 1'b0;
                irq_req[i] <= 1'b0;
            end
        end else begin
            for(int i = 0; i < NUM_IRQS; i++)begin
                irq_meta[i] <= irq_in[i];
                irq_req[i] <= irq_meta[i];
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
    logic [$clog2(NUM_IRQS)-1:0] serviced_id, serviced_id_next;
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
            state <= IDLE;
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
            IDLE: begin
                s_axi_lite.awready = 1'b1;
                s_axi_lite.arready = 1'b1;

                if(s_axi_lite.arvalid)begin
                    in_service_next = 1'b1;
                    next_state = LITE_SENDING_READ_DATA;
                    araddr_next = s_axi_lite.araddr;
                end

                if(s_axi_lite.awvalid)begin
                    next_state = LITE_RECEIVING_WRITE_DATA;
                    awaddr_next = s_axi_lite.awaddr;
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

                    CONTEXT_CLAIM_COMPLETE:begin
                        s_axi_lite.rresp = 2'b00;
                        
                        // Return highest priority ID
                        automatic logic found = 0;
                        automatic int id = 0;

                        for (int i = NUM_IRQS-1; i >= 0; i--) begin
                            if (!found && ip[i] && ~in_service) begin
                                found = 1;
                                id = i + 1;  // IDs are still 1-based
                                // pending flags are handled by the gateways
                                in_service_next = 1'b1; // Flag as being serviced
                                serviced_id_next = i + 1;
                            end
                        end

                        s_axi_lite.rdata = id;
                    end

                    default: begin
                        // Return error + dummy / noticable value 
                        s_axi_lite.rresp = 2'b11;
                        s_axi_lite.rdata = 32'hFFFFFFFF;
                    end
                endcase

                if(s_axi_lite.rready)begin
                    next_state = IDLE;
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
                            if(s_axi_lite.wdata == serviced_id)begin
                                in_service_next = 0;
                            end
                        end

                        default: $display("not a valid address pal!");
                    endcase

                    next_state =  LITE_SENDING_WRITE_RES
                end
            end

            LITE_SENDING_WRITE_RES:begin
                s_axi_lite.bresp = 2'b00;
                s_axi_lite.bvalid = 1'b1;

                if(s_axi_lite.bready)begin
                    next_state = IDLE;
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

    // Registers for enable and pending interrupts
    logic [NUM_IRQS-1:0] enabled, enabled_next;

    always_comb begin : set_target_notification
        ext_irq_o = |ip && ~in_service;
    end

    always_ff @(posedge clk) begin : enabled_register
        if(~rst_n) begin
            enabled <= 0;
        end
        else begin
            enabled <= enabled_next;
        end
    end


endmodule
