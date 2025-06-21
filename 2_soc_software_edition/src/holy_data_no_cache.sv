/** UNCACHED DATA MEMORY MODULE
*
*   Author : BRH
*   Project : Holy Core SoC & Software edition
*   Description : A module able to get request for the CPU and load / write from
*                 an AXI LITE Slave directly. This system is very suited for
*                 simple SoC with lots of MMIO operation and with tighlty coupled
*                 memory system (e.g. BRAM on an FPGA).
*
*   Created 06/25
*/

import holy_core_pkg::*;

module holy_data_no_cache #(
    parameter CACHE_SIZE = 128
)(
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // AXI Clock, separate necessary as arbitrer can't output it.
    input logic aclk,

    // CPU Interface
    input logic [31:0]  address,
    input logic [31:0]  write_data,
    input logic         read_enable,
    input logic         write_enable,
    input logic [3:0]   byte_enable,
    output logic [31:0] read_data,
    output logic        cache_stall,

    // AXI LITE Interface for external requests
    axi_lite_if.master axi_lite,

    // State informations for arbitrer (also used for debugging)
    output cache_state_t cache_state,

    // Debug signals
    output logic       debug_seq_stall,
    output logic       debug_comb_stall,
    output logic [3:0] debug_next_cache_state
);
    // debug assignements
    assign debug_seq_stall = seq_stall;
    assign debug_comb_stall = comb_stall;
    assign debug_next_cache_state = next_state;

    // AXI LITE's result for reads will be stored here
    logic [31:0]                    axi_lite_read_result; 
    // IMPORTANT : axi_lite_tx_done is flag used to determine if R or W
    // tx has been completed it is set to 1 after a successful AXI LITE TX
    // to avoid going into a NON IDLE state right away and let the core
    // fetch a new instruction. This also means it stays high for 1 clock cycle
    // only before going low again, thus allowing the cache to go NON-IDLE again
    // on the non cachable range.
    logic                           axi_lite_tx_done, next_axi_lite_tx_done;

    // INCOMING CACHE REQUEST SIGNALS

    // Don't do anything if byte enable is not set.
    logic actual_write_enable;
    assign actual_write_enable = write_enable & |byte_enable;

    // Stall is asserted async but deasserted in sync !
    // Thus the comb and seq stall logic.
    logic comb_stall, seq_stall;
    assign comb_stall = (next_state != IDLE) && (read_enable | actual_write_enable);
    assign cache_stall = (comb_stall | seq_stall) && ~axi_lite_tx_done;

    // =======================
    // FSM LOGIC
    // =======================
    cache_state_t state, next_state;

    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            seq_stall <= 1'b0;
            axi_lite_tx_done <= 1'b0;
        end else begin
            seq_stall <= comb_stall;
            axi_lite_tx_done <= next_axi_lite_tx_done;

            if(axi_lite.rvalid && state == LITE_RECEIVING_READ_DATA && axi_lite.rready) begin
                // Write incomming axi lite read
                axi_lite_read_result <= axi_lite.rdata;
            end
        end
    end

    // AXI CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge aclk) begin
        if (~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // =======================
    // READ & MAIN FSM LOGIC
    // =======================
    always_comb begin
        // State transition 
        next_state = state; // Default
        next_axi_lite_tx_done = axi_lite_tx_done;

        // AXI LITE DEFAULT
        axi_lite.wstrb = byte_enable;
        axi_lite.araddr  = address;
        axi_lite.wdata   = write_data;
        axi_lite.awaddr  = {address[31:2],2'b00};
        axi_lite.arvalid = 0;
        axi_lite.awvalid = 0;
        axi_lite.wvalid  = 0;
        axi_lite.bready  = 0;
        axi_lite.rready  = 0;

        // READ DATA ALWAYS OUT
        read_data = axi_lite_read_result;

        case (state)
            IDLE: begin
                if(read_enable && write_enable) $display("ERROR, CAN'T READ AND WRITE AT THE SAME TIME!!!");
                
                else if ( read_enable & ~axi_lite_tx_done ) begin
                    next_state = LITE_SENDING_READ_REQ;
                end

                else if ( actual_write_enable & ~axi_lite_tx_done ) begin
                    next_state = LITE_SENDING_WRITE_REQ;
                end


                // -----------------------------------
                // IDLE AXI LITE SIGNALS : no request

                // no write
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b0;
                // no read
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b0;

                if(axi_lite_tx_done) begin
                    // axi lite done flag auto reset
                    next_axi_lite_tx_done = 1'b0;
                end
            end

            LITE_SENDING_WRITE_REQ : begin
                // NON CACHED DATA, WE WRITE DIRECTLY TO REQ ADDRESS
                axi_lite.awaddr = address;
                
                if(axi_lite.awready) next_state = LITE_SENDING_WRITE_DATA;

                // SENDING_WRITE_REQ AXI SIGNALS : address request
                // No write
                axi_lite.awvalid = 1'b1;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b0;
                // No read
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b0;
            end

            LITE_SENDING_WRITE_DATA : begin
                // Data to write is the regular write data
                if(axi_lite.wready) begin
                    next_state = LITE_WAITING_WRITE_RES;
                end

                axi_lite.wdata = write_data;

                // SENDING_WRITE_DATA AXI SIGNALS : sending data
                // Write stuff
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b1;
                axi_lite.bready = 1'b0;
                // No read
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b0;

            end

            LITE_WAITING_WRITE_RES : begin
                if(axi_lite.bvalid && (axi_lite.bresp == 2'b00)) begin
                    next_state = IDLE;
                    // flag tx as done as well
                    next_axi_lite_tx_done = 1'b1;
                end else if(axi_lite.bvalid && (axi_lite.bresp != 2'b00)) begin
                    // TODO : TRAP HERE (?)
                    $display("ERROR WRITING TO MAIN MEMORY !");
                    next_state = IDLE;
                end

                // SENDING_WRITE_DATA AXI SIGNALS : ready for response
                // No write
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b1;
                // No read
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b0;
            end

            LITE_SENDING_READ_REQ : begin
                if(axi_lite.arready) begin
                    next_state = LITE_RECEIVING_READ_DATA;
                end

                // SENDING_READ_REQ axi_lite SIGNALS : address request
                // No write
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b0;
                // No read but address is okay
                axi_lite.arvalid = 1'b1;
                axi_lite.rready = 1'b0;
            end

            LITE_RECEIVING_READ_DATA : begin
                if (axi_lite.rvalid) begin
                    next_state = IDLE;
                    // flag tx as done as well
                    next_axi_lite_tx_done = 1'b1;
                end
            
                // AXI LITE Signals
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b0;
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b1;
            end
            
            default : begin
                $display("CACHE FSM STATE ERROR");
                // TODO : TRAP HERE (?)
            end
        endcase
    end

    wire [31:0] byte_enable_mask;
    assign byte_enable_mask = {
        {8{byte_enable[3]}},
        {8{byte_enable[2]}},
        {8{byte_enable[1]}},
        {8{byte_enable[0]}}
    };

endmodule
