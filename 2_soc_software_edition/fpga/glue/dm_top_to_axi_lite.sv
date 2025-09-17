/** Glue logic for debug module
*
*   Author : BRH
*/

import holy_core_pkg::*;

module dm_top_to_axi_lite (
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic aclk,
    input logic rst_n,

    // dm_top Interface
    input logic         req_i,
    input logic [31:0]  add_i,
    input logic         we_i,
    input logic [31:0]  wdata_i,
    input logic [3:0]   be_i,
    output logic         gnt_o,
    output logic         r_valid_o,
    output logic [31:0]  r_rdata_o,

    // AXI LITE Interface for external requests
    axi_lite_if.master out_if_axil_m,

    // (for debugging)
    output cache_state_t cache_state
);

    // AXI LITE's result for reads will be stored here
    logic [31:0]                    axi_lite_read_result;

    // Don't do anything if byte enable is not set.
    logic actual_write_enable;
    assign actual_write_enable = we_i & |be_i;

    // =======================
    // FSM LOGIC
    // =======================
    cache_state_t state, next_state;
    assign cache_state = state;// out for muxes hints

    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            axi_lite_read_result <='0;
        end else begin
            if(out_if_axil_m.rvalid && state == LITE_RECEIVING_READ_DATA && out_if_axil_m.rready) begin
                // Write incomming axi lite read
                axi_lite_read_result <= out_if_axil_m.rdata;
            end
        end
    end

    // AXI CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
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

        // AXI LITE DEFAULT
        out_if_axil_m.wstrb = be_i;
        out_if_axil_m.araddr  = add_i;
        out_if_axil_m.wdata   = wdata_i;
        out_if_axil_m.awaddr  = {add_i[31:2],2'b00};
        out_if_axil_m.arvalid = 0;
        out_if_axil_m.awvalid = 0;
        out_if_axil_m.wvalid  = 0;
        out_if_axil_m.bready  = 0;
        out_if_axil_m.rready  = 0;

        // READ DATA ALWAYS OUT
        r_rdata_o = axi_lite_read_result;
        r_valid_o = 0;
        gnt_o = 0;


        case (state)
            IDLE: begin
                if ( req_i ) begin
                    // WRITE REQ
                    if ( we_i ) begin
                        next_state = LITE_SENDING_WRITE_REQ;
                    end
                    // READ REQ
                    else begin
                        next_state = LITE_SENDING_READ_REQ;
                    end
                end


                // -----------------------------------
                // IDLE AXI LITE SIGNALS : no request

                // no write
                out_if_axil_m.awvalid = 1'b0;
                out_if_axil_m.wvalid = 1'b0;
                out_if_axil_m.bready = 1'b0;
                // no read
                out_if_axil_m.arvalid = 1'b0;
                out_if_axil_m.rready = 1'b0;
            end

            LITE_SENDING_WRITE_REQ : begin
                // NON CACHED DATA, WE WRITE DIRECTLY TO REQ ADDRESS
                out_if_axil_m.awaddr = add_i;
                
                if(out_if_axil_m.awready) next_state = LITE_SENDING_WRITE_DATA;

                // SENDING_WRITE_REQ AXI SIGNALS : address request
                // No write
                out_if_axil_m.awvalid = 1'b1;
                out_if_axil_m.wvalid = 1'b0;
                out_if_axil_m.bready = 1'b0;
                // No read
                out_if_axil_m.arvalid = 1'b0;
                out_if_axil_m.rready = 1'b0;
            end

            LITE_SENDING_WRITE_DATA : begin
                // Data to write is the regular write data
                if(out_if_axil_m.wready) begin
                    next_state = LITE_WAITING_WRITE_RES;
                end

                out_if_axil_m.wdata = wdata_i;

                // SENDING_WRITE_DATA AXI SIGNALS : sending data
                // Write stuff
                out_if_axil_m.awvalid = 1'b0;
                out_if_axil_m.wvalid = 1'b1;
                out_if_axil_m.bready = 1'b0;
                // No read
                out_if_axil_m.arvalid = 1'b0;
                out_if_axil_m.rready = 1'b0;

            end

            LITE_WAITING_WRITE_RES : begin
                if(out_if_axil_m.bvalid && (out_if_axil_m.bresp == 2'b00)) begin
                    gnt_o = 1;
                    if(~req_i)begin
                        next_state = IDLE;
                    end
                end else if(out_if_axil_m.bvalid && (out_if_axil_m.bresp != 2'b00)) begin
                    // TODO : TRAP HERE (?)
                    $display("ERROR WRITING TO MAIN MEMORY !");
                    gnt_o = 1;
                    if(~req_i)begin
                        next_state = IDLE;
                    end
                end

                // SENDING_WRITE_DATA AXI SIGNALS : ready for response
                // No write
                out_if_axil_m.awvalid = 1'b0;
                out_if_axil_m.wvalid = 1'b0;
                out_if_axil_m.bready = 1'b1;
                // No read
                out_if_axil_m.arvalid = 1'b0;
                out_if_axil_m.rready = 1'b0;
            end

            LITE_SENDING_READ_REQ : begin
                if(out_if_axil_m.arready) begin
                    next_state = LITE_RECEIVING_READ_DATA;
                end

                // SENDING_READ_REQ axi_lite SIGNALS : address request
                // No write
                out_if_axil_m.awvalid = 1'b0;
                out_if_axil_m.wvalid = 1'b0;
                out_if_axil_m.bready = 1'b0;
                // No read but address is okay
                out_if_axil_m.arvalid = 1'b1;
                out_if_axil_m.rready = 1'b0;
            end

            LITE_RECEIVING_READ_DATA : begin
                if (out_if_axil_m.rvalid) begin
                    if(~req_i)begin
                        next_state = IDLE;
                    end
                    r_rdata_o = out_if_axil_m.rdata;
                    gnt_o = 1;
                end
            
                // AXI LITE Signals
                out_if_axil_m.awvalid = 1'b0;
                out_if_axil_m.wvalid = 1'b0;
                out_if_axil_m.bready = 1'b0;
                out_if_axil_m.arvalid = 1'b0;
                out_if_axil_m.rready = 1'b1;
            end
            
            default : begin
                $display("CACHE FSM STATE ERROR");
                // TODO : TRAP HERE (?)
            end
        endcase
    end

endmodule
