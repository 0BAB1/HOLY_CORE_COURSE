/** UNCACHED DATA MEMORY MODULE (HANDSHAKE VERSION)
*
*   Author : BRH
*   Project : Holy Core SoC & Software edition
*   Description : A module able to get request for the CPU and load / write from
*                 an AXI LITE Slave directly. This system is very suited for
*                 simple SoC with lots of MMIO operation and with tighlty coupled
*                 memory system (e.g. BRAM on an FPGA).
*
*   Updated 11/25 - Added req_valid/req_ready handshake interface
*/

import holy_core_pkg::*;

module holy_no_cache (
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // CPU Interface
    input logic [31:0]  address,
    input logic [31:0]  write_data,
    input logic [3:0]   byte_enable,
    // handshake
    input logic         req_valid,
    output logic        req_ready,
    input logic         req_write, // 0->R // 1->W
    // read out
    output logic [31:0] read_data,
    output logic        read_valid,
    input logic         read_ack,

    // AXI LITE Interface for external requests
    axi_lite_if.master axi_lite,

    // State informations for arbitrer (also used for debugging)
    output cache_state_t cache_state
);

    // Ready when IDLE
    assign req_ready = (state == IDLE);
    
    // Request accepted flag
    logic req_accepted;
    assign req_accepted = req_valid && req_ready;

    // Read valid when in READ_OK state
    assign read_valid = (state == READ_OK);

    // Request latching
    logic                       pending_write, next_pending_write;
    logic [31:0]                pending_addr, next_pending_addr;
    logic [31:0]                pending_data, next_pending_data;
    logic [3:0]                 pending_byte_enable, next_pending_byte_enable;

    // AXI LITE's result for reads
    logic [31:0] axi_lite_read_result;

    // =======================
    // FSM LOGIC
    // =======================
    cache_state_t state, next_state;
    assign cache_state = state;

    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pending_write <= 1'b0;
            pending_addr <= '0;
            pending_data <= '0;
            pending_byte_enable <= '0;
            axi_lite_read_result <= '0;
            
        end else begin
            pending_write <= next_pending_write;
            pending_addr <= next_pending_addr;
            pending_data <= next_pending_data;
            pending_byte_enable <= next_pending_byte_enable;

            if(axi_lite.rvalid && state == LITE_RECEIVING_READ_DATA && axi_lite.rready) begin
                axi_lite_read_result <= axi_lite.rdata;
            end
        end
    end

    // FSM STATE REGISTER
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // =======================
    // FSM TRANSITION LOGIC
    // =======================
    always_comb begin
        // Defaults
        next_state = state;
        next_pending_write = pending_write;
        next_pending_addr = pending_addr;
        next_pending_data = pending_data;
        next_pending_byte_enable = pending_byte_enable;

        // AXI LITE DEFAULTS
        axi_lite.wstrb = pending_byte_enable;
        axi_lite.araddr  = pending_addr;
        axi_lite.wdata   = pending_data;
        axi_lite.awaddr  = {pending_addr[31:2], 2'b00};
        axi_lite.arvalid = 0;
        axi_lite.awvalid = 0;
        axi_lite.wvalid  = 0;
        axi_lite.bready  = 0;
        axi_lite.rready  = 0;

        // READ DATA OUTPUT
        read_data = axi_lite_read_result;

        case (state)
            IDLE: begin
                // Accept new request
                if (req_accepted) begin
                    // Latch the request
                    next_pending_write = req_write;
                    next_pending_addr = address;
                    next_pending_data = write_data;
                    next_pending_byte_enable = byte_enable;
                    
                    if (req_write) begin
                        next_state = LITE_SENDING_WRITE_REQ;
                    end else begin
                        next_state = LITE_SENDING_READ_REQ;
                    end
                end
            end

            LITE_SENDING_WRITE_REQ: begin
                axi_lite.awaddr = pending_addr;
                axi_lite.awvalid = 1'b1;
                
                if (axi_lite.awready) begin
                    next_state = LITE_SENDING_WRITE_DATA;
                end
            end

            LITE_SENDING_WRITE_DATA: begin
                axi_lite.wdata = pending_data;
                axi_lite.wstrb = pending_byte_enable;
                axi_lite.wvalid = 1'b1;
                
                if (axi_lite.wready) begin
                    next_state = LITE_WAITING_WRITE_RES;
                end
            end

            LITE_WAITING_WRITE_RES: begin
                axi_lite.bready = 1'b1;
                
                if (axi_lite.bvalid) begin
                    if (axi_lite.bresp == 2'b00) begin
                        next_state = IDLE;
                        next_pending_write = 1'b0;
                    end else begin
                        $display("ERROR WRITING TO MAIN MEMORY!");
                        next_state = IDLE;
                    end
                end
            end

            LITE_SENDING_READ_REQ: begin
                axi_lite.araddr = pending_addr;
                axi_lite.arvalid = 1'b1;
                
                if (axi_lite.arready) begin
                    next_state = LITE_RECEIVING_READ_DATA;
                end
            end

            LITE_RECEIVING_READ_DATA: begin
                axi_lite.rready = 1'b1;
                
                if (axi_lite.rvalid) begin
                    next_state = READ_OK;
                end
            end
            
            READ_OK: begin
                // Data is valid, wait for ack
                if (read_ack) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                $display("CACHE FSM STATE ERROR");
            end
        endcase
    end

endmodule