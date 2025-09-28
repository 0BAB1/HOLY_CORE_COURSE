/** CACHE MODULE (INSTRUCTION)
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : A 1 way direct mapped cache.
*                 Implementing AXI to request data from outside main memory.
*                 With a CPU interface for basic core request with stall signal.
*                 This cache only fetches 128x32bits word blocks at a time.
*                 So it's mainly used as a basic instruction cache. It supports
*                 Write back (automatic and manual flueshes) so it may be used
*                 as some basic non-coherent data cache.
*
*   Created 11/24
*   Modification : 05/25 (add manual flush support from incomming csr flag)
*   Modification : 07/25 (add a cache valid output flag)
*
*   IMPORTANT NOTE : this cache is AXI only and very basic. It is NOT USED
*                    ANYMORE in the 2_soc_edition.
*/

import holy_core_pkg::*;

module holy_cache #(
    parameter CACHE_SIZE = 128
)(
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // CPU Interface
    input logic [31:0]  address,
    input logic [31:0]  write_data,
    input logic         read_enable,
    input logic         write_enable,
    input logic [3:0]   byte_enable,
    input logic         csr_flush_order,
    output logic [31:0] read_data,
    output logic        cache_stall,

    // AXI Interface for external requests
    axi_if.master axi,

    // State informations for arbitrer
    output cache_state_t cache_state,

    // Valid flag, used in SoC edition
    // to avoid flagging reseted content as
    // illegal OPs
    output logic cache_valid,

    // debug signals
    output logic [6:0] set_ptr_out,
    output logic [6:0] next_set_ptr_out
);
    assign set_ptr_out = set_ptr;
    assign next_set_ptr_out = next_set_ptr;

    // Here is how a cache line is organized:
    // | DIRTY | VALID | BLOCK TAG | INDEX/SET | OFFSET | DATA |
    // | FLAGS         | ADDRESS INFOS                  | DATA |

    // CACHE TABLE DECLARATION
    logic [CACHE_SIZE-1:0][31:0]    cache_data;
    logic [31:9]                    cache_block_tag; // direct mapped cache so only one block, only one tag
    // logic                           cache_valid;  // is the current block valid ? (output now)
    logic                           next_cache_valid;
    logic                           cache_dirty;
    // register to retain info on wether we are writing back because of miss or because of CSR order
    logic                           csr_flushing, next_csr_flushing;

    // INCOMING CACHE REQUEST SIGNALS
    logic [31:9]                    req_block_tag;
    assign req_block_tag = address[31:9];
    // requested place in cache, written / read if tag hits
    logic [8:2] req_index;
    assign req_index = address[8:2];

    // HIT LOGIC
    logic hit;
    assign hit = (req_block_tag == cache_block_tag) && cache_valid;

    // STALL LOGIC
    logic actual_write_enable;
    assign actual_write_enable = write_enable & |byte_enable;
    logic comb_stall, seq_stall;
    assign comb_stall = (next_state != IDLE) | (~hit & (read_enable | actual_write_enable));
    assign cache_stall = comb_stall | seq_stall;

    // =======================
    // CACHE LOGIC
    // =======================
    cache_state_t state, next_state;

    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            cache_valid <= 1'b0;
            cache_dirty <= 1'b0;
            seq_stall <= 1'b0;
            csr_flushing <= 1'b0;
        end else begin
            cache_valid <= next_cache_valid;
            seq_stall <= comb_stall;

            if(hit && write_enable & state == IDLE) begin
                cache_data[req_index] <= (cache_data[req_index] & ~byte_enable_mask) | (write_data & byte_enable_mask);
                cache_dirty <= 1'b1;
            end else if(axi.rvalid & state == RECEIVING_READ_DATA & axi.rready) begin
                // Write incomming axi read
                cache_data[set_ptr] <= axi.rdata;
                if(axi.rready & axi.rlast) begin
                    cache_block_tag <= req_block_tag;
                    cache_dirty <= 1'b0;
                end
            end

            csr_flushing <= next_csr_flushing;
        end
    end

    // AXI CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= IDLE;
            set_ptr <= 7'd0;
        end else begin
            state <= next_state;
            set_ptr <= next_set_ptr;
        end
    end

    // Async Read logic & AXI SIGNALS declaration !
    always_comb begin
        next_state = state; // Default
        next_cache_valid = cache_valid;
        axi.wlast = 1'b0;
        // the data being send is always set, "ready to go"
        axi.wdata = cache_data[set_ptr];
        cache_state = state;
        next_set_ptr = set_ptr;
        // csr flushing keeps value by default, only set at beginning of flush and deset a end of flush
        next_csr_flushing = csr_flushing;

        case (state)
            IDLE: begin
                // when idling, we simple read and write, no problem !
                if(read_enable && write_enable) $display("ERROR, CAN'T READ AND WRITE AT THE SAME TIME!!!");

                else if(hit && read_enable) begin
                    // async reads
                    read_data = cache_data[req_index];
                end

                else if( csr_flush_order ) begin
                    // don't forget to keep in mind that we are flushing from order
                    // which will bypass reading back
                    next_csr_flushing = 1'b1;
                    // also, we force write back state next
                    next_state = SENDING_WRITE_REQ;
                end

                else if( (~hit && (read_enable ^ actual_write_enable)) & ~csr_flush_order) begin
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

                // Defaults to 0
                next_set_ptr = 7'd0;
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

                if(axi.wready) begin
                    next_set_ptr = set_ptr + 1;
                end
                
                if(set_ptr == 7'd127) begin
                    axi.wlast = 1'b1;
                    if(axi.wready) begin
                        next_state = WAITING_WRITE_RES;
                    end
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
                    // END THE WRITE TRANSACTION
                    if(csr_flushing) begin
                        // if the wb was CSR order, we reset csr flushing and go back to IDLE
                        next_state = IDLE;
                        next_csr_flushing = 0'b0;
                    end else begin
                        // if it was miss wb, we go on with read...
                        next_state = SENDING_READ_REQ;
                    end
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

            RECEIVING_READ_DATA: begin
        
                if (axi.rvalid) begin
                    // Increment pointer on valid data
                    next_set_ptr = set_ptr + 1;
            
                    if (axi.rlast) begin
                        // Transition to IDLE on the last beat
                        next_state = IDLE;
                        next_cache_valid = 1'b1;
                    end
                end
            
                // AXI Signals
                axi.awvalid = 1'b0;
                axi.wvalid = 1'b0;
                axi.bready = 1'b0;
                axi.arvalid = 1'b0;
                axi.rready = 1'b1;
            end
            
            default : begin
                $display("CACHE FSM SATETE ERROR");
            end
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
