/**
 *   HOLY BOOT ROM
 *
 *   Description: 
 *      Simple boot ROM with an infinite loop instruction.
 *      Implemented as an AXI Lite slave using axi_lite_if interface.
 */

import holy_core_pkg::*;

module holy_boot_rom #(
    parameter BASE_ADDR = 0
)(
    input  logic         clk,
    input  logic         rst_n,
    axi_lite_if.slave    axi
);

    logic [31:0] rom_data;

    boot_rom holy_rom (
        .clk(clk),
        .addr(araddr),
        .data_out(rom_data)
    );

    axi_state_slave_t state, next_state;
    logic [31:0] awaddr, awaddr_next;
    logic [31:0] araddr, araddr_next;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state   <= SLAVE_IDLE;
            awaddr  <= 32'd0;
            araddr  <= 32'd0;
        end else begin
            state   <= next_state;
            awaddr  <= awaddr_next;
            araddr  <= araddr_next;
        end
    end

    // Combinational logic
    always_comb begin
        // Default assignments
        next_state    = state;
        awaddr_next   = awaddr;
        araddr_next   = araddr;

        axi.awready   = 1'b0;
        axi.wready    = 1'b0;
        axi.bresp     = 2'b00;
        axi.bvalid    = 1'b0;
        axi.arready   = 1'b0;
        axi.rdata     = 32'h6f;
        axi.rvalid    = 1'b0;
        axi.rresp     = 2'b00;

        case (state)
            SLAVE_IDLE: begin
                axi.awready = 1'b1;
                axi.arready = 1'b1;

                if (axi.arvalid) begin
                    next_state  = LITE_SENDING_READ_DATA;
                    araddr_next = axi.araddr - BASE_ADDR;
                end
                if (axi.awvalid) begin
                    next_state  = LITE_RECEIVING_WRITE_DATA;
                    awaddr_next = axi.awaddr - BASE_ADDR;
                end
            end

            LITE_SENDING_READ_DATA: begin
                axi.rvalid = 1'b1;
                axi.rresp  = 2'b00;
                axi.rdata  = rom_data; // Infinite loop instruction (RISC-V JAL)

                if (axi.rready) begin
                    next_state = SLAVE_IDLE;
                end
            end

            LITE_RECEIVING_WRITE_DATA: begin
                axi.wready = 1'b1;
                if (axi.wvalid) begin
                    next_state = LITE_SENDING_WRITE_RES;
                end
            end

            LITE_SENDING_WRITE_RES: begin
                axi.bresp  = 2'b00;
                axi.bvalid = 1'b1;
                if (axi.bready) begin
                    next_state = SLAVE_IDLE;
                end
            end

            default: begin
                next_state = SLAVE_IDLE;
                $display("FSM STATE ERROR");
            end
        endcase
    end

endmodule

