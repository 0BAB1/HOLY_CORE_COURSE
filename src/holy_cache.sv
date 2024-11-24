/** CACHE MODULE
*
*   Author : BABIN-RIBY Hugo
*   Project : Holy Core V2
*   Description : A 1 way direct mapped cache.
*   Implementing AXI to request data from outside main memory.
*   The goal is to allow the user to connect its own memory on FPGA.
*/

import holy_core_pkg::*;

module holy_cache #(
    parameter CACHE_SIZE = 128 // Number of sets / words in cache
)(
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // AXI CLOCK
    input logic aclk,

    // CPU Interface
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic read_enable,
    input logic write_enable,
    input logic [3:0]byte_enable,
    output logic [31:0] read_data,
    output logic cache_stall,

    // AXI Interface for external requests
    axi_if.master axi,

    // State informations for arbitrer
    output cache_state_t cache_state
);
    localparam INDEX_WIDTH = $clog2(CACHE_SIZE);

    // Here is how a cache line is organized:
    // | DIRTY | VALID | BLOCK TAG | INDEX/SET | OFFSET | DATA |
    // | FLAGS         | ADDRESS INFOS                  | DATA |

    /* verilator lint_off MULTIDRIVEN */

    // CACHE TABLE DECLARATION (hardcoded for now, TODO : fix that)
    logic [31:0]                    cache_data          [0:CACHE_SIZE-1];
    logic [31:9]                    cache_block_tag; // direct mapped cache so only one block, only one tag
    logic                           cache_valid;  // is the current block valid ?
    logic                           next_cache_valid;
    logic                           cache_dirty;

    // INCOMING CACHE REQUEST SIGNALS
    logic [31:9]                    req_block_tag;
    assign req_block_tag = address[31:9];
    logic [8:2] req_index;
    assign req_index = address[8:2];

    // HIT LOGIC
    logic hit;
    assign hit = (req_block_tag == cache_block_tag) && cache_valid;

    // STALL LOGIC
    assign cache_stall = (next_state != IDLE) | (~hit & (read_enable | write_enable));

    // =======================
    // CACHE LOGIC
    // =======================
    cache_state_t state, next_state;

    // CPU IF write logic (read is async)
    always_ff @(posedge clk) begin
        // Write to cache
        if(hit && write_enable) begin
            // async reads
            cache_data[req_index] <= (cache_data[req_index] & ~byte_enable_mask) | (write_data & byte_enable_mask);
            cache_dirty <= 1'b1;
        end
    end

    // AXI State machine logic
    always_ff @(posedge aclk or negedge rst_n or negedge axi.aresetn) begin
        if (~rst_n) begin
            state <= IDLE;
            cache_valid <= 1'b0;
            set_ptr <= 7'd0;
            cache_dirty <= 1'b0;
            cache_block_tag <= 23'b0;
        end else begin
            state <= next_state;
            cache_valid <= next_cache_valid;
            set_ptr <= next_set_ptr;

            case (state)
                RECEIVING_READ_DATA: begin
                    if(axi.rvalid) begin
                        cache_data[set_ptr] <= axi.rdata;
                        if(axi.rready & axi.rlast) begin
                            cache_block_tag <= req_block_tag;
                            cache_dirty <= 1'b0;
                        end
                    end
                end
                default : begin end
            endcase
        end
    end

    /* verilator lint_on MULTIDRIVEN */

    // Async Read logic & AXI SIGNALS declaration !
    always_comb begin
        next_state = state; // Default
        next_cache_valid = cache_valid;
        axi.wlast = 1'b0;
        // the data being send is always set, "ready to go"
        axi.wdata = cache_data[set_ptr];
        cache_state = state;

        case (state)
            IDLE: begin
                // when idling, we simple read and write, no problem !
                if(read_enable && write_enable) $display("ERROR, CAN'T READ AND WRITE AT THE SAME TIME!!!");

                else if(hit && read_enable) begin
                    // async reads
                    read_data = cache_data[req_index];
                end

                else if(~hit && (read_enable ^ write_enable)) begin
                    // switch state to handle the MISS, if data is dirty, we have to write first
                    case(cache_dirty)
                        1'b1 : next_state = SENDING_WRITE_REQ;
                        1'b0 : next_state = SENDING_READ_REQ;
                    endcase
                end

                // IDLE AXI SIGNALS : no request
                // No write
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b0;
                axi.bready = 1'b0;
                // No read
                axi.arvalid = 1'b0;
                axi.rready = 1'b0;

            end
            SENDING_WRITE_REQ: begin
                // HANDLE MISS WITH DIRTY CACHE : Update main memory first
                // when we send a write-back request, we write the CURRENT cache data !
                axi.awaddr = {cache_block_tag, 7'b0000000, 2'b00}; // tag, set, offset
                
                if(axi.awready) next_state = SENDING_WRITE_DATA;

                // SENDING_WRITE_REQ AXI SIGNALS : address request
                // No write
                axi.awvalid = 1'b1;
                axi.wvalid = 1'b0;
                axi.bready = 1'b0;
                // No read
                axi.arvalid = 1'b0;
                axi.rready = 1'b0;
            end

            SENDING_WRITE_DATA : begin
                if(set_ptr == 7'd127) begin
                    next_state = WAITING_WRITE_RES;
                    axi.wlast = 1'b1;
                end

                if(axi.wready) begin
                    next_set_ptr = set_ptr + 1;
                end

                // SENDING_WRITE_DATA AXI SIGNALS : sending data
                // Write stuff
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b1;
                axi.bready = 1'b0;
                // No read
                axi.arvalid = 1'b0;
                axi.rready = 1'b0;
            end

            WAITING_WRITE_RES: begin
                if(axi.bvalid && (axi.bresp == 2'b00)) begin// if response is OKAY
                    next_state = SENDING_READ_REQ;
                end else if(axi.bvalid && (axi.bresp != 2'b00)) begin
                    $display("ERROR WRTING TO MAIN MEMORY !");
                end

                // SENDING_WRITE_DATA AXI SIGNALS : ready for response
                // No write
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b0;
                axi.bready = 1'b1;
                // No read
                axi.arvalid = 1'b0;
                axi.rready = 1'b0;
            end

            SENDING_READ_REQ : begin
                // HANDLE MISS : Read
                axi.araddr = {req_block_tag, 7'b0000000, 2'b00}; // tag, set, offset
                
                if(axi.arready) begin
                    next_state = RECEIVING_READ_DATA;
                end

                // SENDING_READ_REQ AXI SIGNALS : address request
                // No write
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b0;
                axi.bready = 1'b0;
                // No read but address is okay
                axi.arvalid = 1'b1;
                axi.rready = 1'b0;
            end

            RECEIVING_READ_DATA : begin
                if(axi.rvalid) begin// if response is OKAY
                    next_set_ptr = set_ptr + 1;
                    if (axi.rlast) begin
                        next_state = IDLE;
                        next_cache_valid = 1'b1;
                    end
                end
                
                // RECEIVING_READ_DATA AXI SIGNALS : We get the data incomming
                // No write
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b0;
                axi.bready = 1'b0;
                // No read but address is okay
                axi.arvalid = 1'b0;
                axi.rready = 1'b1;
            end
            default : begin end
        endcase
    end

    logic [6:0] set_ptr;
    logic [6:0] next_set_ptr;
    wire [31:0] byte_enable_mask;
    assign byte_enable_mask = {
        {8{byte_enable[3]}},
        {8{byte_enable[2]}},
        {8{byte_enable[1]}},
        {8{byte_enable[0]}}
    };

    // Invariant AXI Signals

    // ADDRESS CHANNELS
    // -----------------
    // WRITE Burst sizes are fixed type & len
    assign axi.awlen = CACHE_SIZE-1; // full cache reloaded each time
    assign axi.awsize = 3'b010; // 2^<awsize> = 2^2 = 4 Bytes
    assign axi.awburst = 2'b01; // INCREMENT
    // READ Burst sizes are fixed type & len
    assign axi.arlen = CACHE_SIZE-1; // full cache reloaded each time
    assign axi.arsize = 3'b010; // 2^<arsize> = 2^2 = 4 Bytes
    assign axi.arburst = 2'b01; // INCREMENT
    // W/R ids are always 0 (TODO maybe not)
    assign axi.awid = 4'b0000;
    assign axi.arid = 4'b0000;

    // DATA CHANNELS
    // -----------------
    // Write data
    assign axi.wstrb = 4'b1111; // We handle data masking in cache itself

endmodule
