/** DATA CACHE MODULE
*
*   Author : BRH
*   Project : Holy Core Perf Edition
*   Description : A 2 way N sets, set-associative cache.
*                 Implementing AXI to request data from outside main memory.
*                 With a CPU interface for basic core request with stall signal.
*                 The goal is to allow the user to connect its own memory on FPGA.
*                 It also supports non cachable ranges, which the use can set
*                 using CSRs.
*
*   Created 11/25
*/

import holy_core_pkg::*;

module holy_data_cache #(
    parameter WORDS_PER_LINE = 16,
    parameter NUM_SETS = 8,
    // MODIFYING THE FOLLOWING IS NOT SUPPORTED. 
    parameter NUM_WAYS = 2 
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
    output logic [31:0] read_data,
    output logic        cache_busy,
    // todo : add data vlid to allow data retrieve before end of bursts
    // to limit blocking times.

    // incomming CSR Orders
    input logic         csr_flush_order,
    input logic [31:0]  non_cachable_base,
    input logic [31:0]  non_cachable_limit,

    // AXI Interface for external requests
    axi_if.master axi,

    // AXI LITE Interface for external requests
    axi_lite_if.master axi_lite,

    // State informations for arbitrer
    output cache_state_t cache_state
);

    // =======================
    // ADDRESS BREAKDOWN
    // =======================
    // Address format: [TAG | SET_INDEX | WORD_OFFSET | BYTE_OFFSET]
    // 32 bits total:
    //   - Byte offset: 2 bits (4 bytes per word)
    //   - Word offset: 4 bits (16 words per line)
    //   - Set index: 3 bits (8 sets)
    //   - Tag: 23 bits (remaining)
    
    localparam WAYS_BITS = $clog2(NUM_WAYS);
    localparam BYTE_OFFSET_BITS = 2;
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam SET_INDEX_BITS   = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - BYTE_OFFSET_BITS - WORD_OFFSET_BITS - SET_INDEX_BITS;

    // warning free markers for loops
    localparam LAST_WORD = WORDS_PER_LINE - 1;
    localparam LAST_SET = NUM_SETS - 1;
    
    wire [TAG_BITS-1:0]         req_tag;
    wire [SET_INDEX_BITS-1:0]   req_set;
    wire [WORD_OFFSET_BITS-1:0] req_word_offset;
    
    assign req_tag         = address[31:31-TAG_BITS+1];
    assign req_set         = address[BYTE_OFFSET_BITS+WORD_OFFSET_BITS +: SET_INDEX_BITS];
    assign req_word_offset = address[BYTE_OFFSET_BITS +: WORD_OFFSET_BITS];

    // =======================
    // Data slots declaration
    // =======================

    // Cache storage: default : 2 ways × 8 sets × 16 words
    logic [31:0]         cache_data  [NUM_WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    logic [TAG_BITS-1:0] cache_tags  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic                cache_valid [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic                cache_dirty [NUM_WAYS-1:0][NUM_SETS-1:0];

    // lru = least recently used, decides which way will 
    logic lru_bits [NUM_SETS-1:0];

    // Signals for cache access
    logic hit_way0, hit_way1, hit;
    logic [NUM_WAYS-1:0] way_hit;
    logic hit_way_select;
    logic victim_way;

    // Control signals
    logic csr_flushing, next_csr_flushing;
    logic csr_flushing_done, next_csr_flushing_done;
    logic comb_stall;

    // AXI Lite transaction tracking
    logic axi_lite_tx_done;
    logic next_axi_lite_tx_done;
    logic [31:0] axi_lite_cached_addr;
    logic [31:0] next_axi_lite_cached_addr;
    logic [31:0] axi_lite_read_result;

    // Non-cachable range check
    logic non_cachable;
    assign non_cachable = (address >= non_cachable_base) && (address < non_cachable_limit);
    
    // Actual write enable (not during non-cachable operations)
    logic actual_write_enable;
    assign actual_write_enable = write_enable && ~non_cachable;

    // =======================
    // HIT DETECTION
    // =======================

    assign hit_way0 = cache_valid[0][req_set] && (cache_tags[0][req_set] == req_tag);
    assign hit_way1 = cache_valid[1][req_set] && (cache_tags[1][req_set] == req_tag);
    assign hit = hit_way0 || hit_way1;
    assign hit_way_select = hit_way1; // 0 if way0 hits, 1 if way1 hits

    // Victim selection for replacement (use LRU)
    assign victim_way = lru_bits[req_set];

    // =======================
    // CACHE LOGIC
    // =======================
    cache_state_t state, next_state;

    // Current way being serviced
    logic current_way, next_current_way;
    // flush indicators
    logic [WAYS_BITS-1:0]       flush_way, next_flush_way;
    logic [SET_INDEX_BITS-1:0]    flush_set, next_flush_set;

    // Word pointer for burst transfers
    logic [WORD_OFFSET_BITS-1:0] word_ptr, next_word_ptr;

    // Cache valid/dirty next state
    logic next_cache_valid  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic next_cache_dirty  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic next_lru_bits     [NUM_SETS-1:0];

    // Stall and busy signals
    logic axi_lite_needs_access;
    assign axi_lite_needs_access =
        (read_enable || write_enable) && non_cachable;
    
    assign comb_stall = 
        (state != IDLE) || 
        (read_enable && ~hit && ~non_cachable) ||
        (actual_write_enable && ~hit) || 
        (csr_flush_order && ~csr_flushing_done) ||
        (axi_lite_needs_access && ~axi_lite_tx_done);

    assign cache_busy = comb_stall;
    
    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            csr_flushing <= 1'b0;
            csr_flushing_done <= 1'b0;
            axi_lite_tx_done <= 1'b0;
            axi_lite_cached_addr <= 32'h00000001;
            // flush reg
            flush_way <= 0;
            flush_set <= 0;
            
            // Initialize all cache lines as invalid
            for (int w = 0; w < NUM_WAYS; w++) begin
                for (int s = 0; s < NUM_SETS; s++) begin
                    cache_valid[w][s] <= 1'b0;
                    cache_dirty[w][s] <= 1'b0;
                    cache_tags[w][s] <= '0;
                end
            end
            
            // Initialize LRU bits
            for (int s = 0; s < NUM_SETS; s++) begin
                lru_bits[s] <= 1'b0;
            end
            
        end else begin
            // Handle writes on cache hit
            if (hit && write_enable && state == IDLE && ~non_cachable) begin
                if (hit_way0) begin
                    cache_data[0][req_set][req_word_offset] <= 
                        (cache_data[0][req_set][req_word_offset] & ~byte_enable_mask) | 
                        (write_data & byte_enable_mask);
                    cache_dirty[0][req_set] <= 1'b1;
                    lru_bits[req_set] <= 1'b1; // Mark way 1 as LRU
                end else begin
                    cache_data[1][req_set][req_word_offset] <= 
                        (cache_data[1][req_set][req_word_offset] & ~byte_enable_mask) | 
                        (write_data & byte_enable_mask);
                    cache_dirty[1][req_set] <= 1'b1;
                    lru_bits[req_set] <= 1'b0; // Mark way 0 as LRU
                end
            end
            
            // Handle cache line fills from AXI
            else if (axi.rvalid && state == RECEIVING_READ_DATA && axi.rready) begin
                cache_data[current_way][req_set][word_ptr] <= axi.rdata;
                if (axi.rlast) begin
                    cache_tags[current_way][req_set] <= req_tag;
                    cache_valid[current_way][req_set] <= 1'b1;
                    cache_dirty[current_way][req_set] <= 1'b0;
                    lru_bits[req_set] <= ~current_way; // Update LRU
                end
            end
            
            // Handle AXI Lite reads
            else if (axi_lite.rvalid && state == LITE_RECEIVING_READ_DATA && axi_lite.rready) begin
                axi_lite_read_result <= axi_lite.rdata;
            end
            
            // Update LRU on read hit
            if (hit && read_enable && state == IDLE && ~non_cachable) begin
                lru_bits[req_set] <= ~hit_way_select;
            end
            
            csr_flushing <= next_csr_flushing;
            csr_flushing_done <= next_csr_flushing_done;
            axi_lite_tx_done <= next_axi_lite_tx_done;
            axi_lite_cached_addr <= next_axi_lite_cached_addr;
            // flush reg
            flush_way <= next_flush_way;
            flush_set <= next_flush_set;
        end
    end

    // =======================
    // AXI & AXI LITE FSM
    // =======================

    // SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= IDLE;
            word_ptr <= '0;
            current_way <= 1'b0;
        end else begin
            state <= next_state;
            word_ptr <= next_word_ptr;
            current_way <= next_current_way;
        end
    end

    // STATE TRANSITION / AXI MASTER  LOGIC
    always_comb begin
        // State transition defaults
        next_state = state;
        next_axi_lite_tx_done = axi_lite_tx_done;
        next_current_way = current_way;
        next_word_ptr = word_ptr;
        // inconditional flushing
        next_csr_flushing = csr_flushing;
        // we deassert flush done flag when the csr flush is no more.
        next_csr_flushing_done = csr_flushing_done ? csr_flush_order : csr_flushing_done;
        next_flush_set = flush_set;
        next_flush_way = flush_way;

        next_axi_lite_cached_addr = axi_lite_cached_addr;

        // AXI LITE DEFAULT
        axi_lite.wstrb = byte_enable;
        axi_lite.wdata = write_data;
        axi_lite.arvalid = 0;
        axi_lite.awvalid = 0;
        axi_lite.wvalid = 0;
        axi_lite.bready = 0;
        axi_lite.rready = 0;
        axi_lite.araddr = 32'h0;
        axi_lite.awaddr = 32'h0;

        // AXI DEFAULT
        axi.wlast = 0;
        axi.arvalid = 0;
        axi.awvalid = 0;
        axi.wvalid = 0;
        axi.bready = 0;
        axi.rready = 0;
        axi.wdata = '0;
        axi.araddr = 32'h0;
        axi.awaddr = 32'h0;

        // MISC OUTPUT DEFAULTS
        cache_state = state;
        read_data = 32'h0;
        cache_state = state;

        case (state)
            IDLE: begin
                if(read_enable && write_enable) $display("ERROR, CAN'T READ AND WRITE AT THE SAME TIME!!!");
                
                else if (csr_flush_order && ~csr_flushing_done) begin
                    next_csr_flushing = 1'b1;
                    next_flush_set = 0;
                    next_flush_way = 0;

                    if(cache_valid[0][0]) begin
                        // if the first set is valid, we flush it
                        // and start the flushing state loop
                        next_state = SENDING_WRITE_REQ;
                    end else begin
                        // if not, we go to FLUSH NEXT STATE which
                        // will skip the WRITE requests until it finds a valid set.
                        next_state = FLUSH_NEXT;
                    end
                end
                
                else if (~hit && (read_enable ^ actual_write_enable) && ~csr_flush_order && ~non_cachable) begin
                    // Cache miss - determine victim way
                    next_current_way = victim_way;
                    
                    // Check if victim line is dirty
                    if (cache_valid[victim_way][req_set] && cache_dirty[victim_way][req_set]) begin
                        next_state = SENDING_WRITE_REQ;
                    end else begin
                        next_state = SENDING_READ_REQ;
                    end
                    next_word_ptr = '0;
                end
                
                else if (read_enable && non_cachable && ~axi_lite_tx_done) begin
                    next_state = LITE_SENDING_READ_REQ;
                end
                else if (write_enable && non_cachable && ~axi_lite_tx_done) begin
                    next_state = LITE_SENDING_WRITE_REQ;
                end

                // READ DATA OUTPUT
                if (hit && read_enable && ~non_cachable) begin
                    if (hit_way0) begin
                        read_data = cache_data[0][req_set][req_word_offset];
                    end else begin
                        read_data = cache_data[1][req_set][req_word_offset];
                    end
                end else if (non_cachable && read_enable) begin
                    read_data = axi_lite_read_result;
                end else begin
                    read_data = '0;
                end

                // we deassert axi lite tx if the read goes low
                // or if we the requested address is different than the 
                // one we read.
                if (axi_lite_tx_done && (~read_enable || (address != axi_lite_cached_addr))) begin
                    next_axi_lite_tx_done = 1'b0;
                end
            end
            
            SENDING_WRITE_REQ: begin
                // Write back dirty cache line
                if (csr_flushing) begin
                    axi.awaddr = {cache_tags[flush_way][flush_set], flush_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                end else begin
                    axi.awaddr = {cache_tags[current_way][req_set], req_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                end
                
                if (axi.awready) begin
                    next_state = SENDING_WRITE_DATA;
                    next_word_ptr = '0;
                end

                axi.awvalid = 1'b1;
            end

            SENDING_WRITE_DATA: begin
                if(csr_flushing)begin
                    axi.wdata = cache_data[flush_way][flush_set][word_ptr];
                end else begin
                    axi.wdata = cache_data[current_way][req_set][word_ptr];
                end
                
                if (axi.wready) begin
                    next_word_ptr = word_ptr + 1;
                end
                
                if (word_ptr == LAST_WORD[WORD_OFFSET_BITS-1:0]) begin
                    axi.wlast = 1'b1;
                    if (axi.wready) begin
                        next_state = WAITING_WRITE_RES;
                    end
                end

                axi.wvalid = 1'b1;
            end

            WAITING_WRITE_RES: begin
                if (axi.bvalid && (axi.bresp == 2'b00)) begin
                    if (csr_flushing) begin
                        
                        // Flushing implies flusshing all sets
                        // from all ways. so we increment flush set / way pointers
                        // and start writing again untils finished.
                        if (flush_set == LAST_SET[SET_INDEX_BITS-1:0]) begin
                            // last set of this way
                            if (flush_way == 1'b1) begin
                                next_state = IDLE;
                                next_csr_flushing = '0;
                                next_csr_flushing_done = 1'b1;
                            end else begin
                                next_flush_way = flush_way + 1'b1;
                                next_flush_set = '0;
                                next_current_way = flush_way + 1'b1;

                                // Depending on the next set's validity, we either
                                // actually flush it OR, if invalid, we just come back here, effectively
                                // skipping it
                                if (cache_valid[next_flush_way][next_flush_set]) begin
                                    next_state = SENDING_WRITE_REQ;
                                end else begin
                                    next_state = FLUSH_NEXT;  // Skip cette ligne
                                end
                            end
                        end else begin
                            // set suivant dans la mm way
                            next_flush_set = flush_set + 1'b1;
                            // same as above
                            if (cache_valid[next_flush_way][next_flush_set]) begin
                                next_state = SENDING_WRITE_REQ;
                            end else begin
                                next_state = FLUSH_NEXT;  // Skip cette ligne
                            end
                        end

                    end else begin
                        // And, of course, if it was a simple write back, which is what happens 99.99999% of the
                        // time, we go and fetch dat data by transitionning to read request state !
                        next_state = SENDING_READ_REQ;
                    end
                end else if (axi.bvalid && (axi.bresp!= 2'b00)) begin
                    $display("ERROR: AXI write response error");
                    $display("TODO : cause a trap");
                end

                axi.bready = 1'b1;
            end

            FLUSH_NEXT: begin
                // advance to next set / way OR end the procedure
                if (flush_set == LAST_SET[SET_INDEX_BITS-1:0]) begin
                    if (flush_way == 1'b1) begin
                        // Flush over
                        next_state = IDLE;
                        next_csr_flushing = '0;
                        next_csr_flushing_done = 1'b1;
                    end else begin
                        next_flush_way = flush_way + 1'b1;
                        next_flush_set = '0;
                    end
                end else begin
                    next_flush_set = flush_set + 1'b1;
                end
                
                // Depending on the next set's validity, we either
                // actually flush it OR, if invalid, we just come back here, effectively
                // skipping it
                if (cache_valid[next_flush_way][next_flush_set]) begin
                    next_state = SENDING_WRITE_REQ;
                end else if ((flush_way != 1'b1) && (flush_set) != 3'b111) begin
                    next_state = FLUSH_NEXT;  // Skip cette ligne
                end
            end

            SENDING_READ_REQ: begin
                axi.araddr = {req_tag, req_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                
                if (axi.arready) begin
                    next_state = RECEIVING_READ_DATA;
                    next_word_ptr = '0;
                end

                axi.arvalid = 1'b1;
            end

            RECEIVING_READ_DATA: begin
                if (axi.rvalid) begin
                    next_word_ptr = word_ptr + 1;
                    
                    if (axi.rlast) begin
                        next_state = IDLE;
                    end
                end

                axi.rready = 1'b1;
            end

            LITE_SENDING_WRITE_REQ: begin
                axi_lite.awaddr = address;
                
                if (axi_lite.awready) begin
                    next_state = LITE_SENDING_WRITE_DATA;
                end

                axi_lite.awvalid = 1'b1;
            end

            LITE_SENDING_WRITE_DATA: begin
                axi_lite.wdata = write_data;
                
                if (axi_lite.wready) begin
                    next_state = LITE_WAITING_WRITE_RES;
                end

                axi_lite.wvalid = 1'b1;
            end

            LITE_WAITING_WRITE_RES: begin
                if (axi_lite.bvalid && (axi_lite.bresp == 2'b00)) begin
                    next_state = IDLE;
                    next_axi_lite_tx_done = 1'b1;
                end else if (axi_lite.bvalid && (axi_lite.bresp != 2'b00)) begin
                    $display("ERROR: AXI Lite write response error");
                    next_state = IDLE;
                end

                axi_lite.bready = 1'b1;
            end

            LITE_SENDING_READ_REQ: begin
                axi_lite.araddr = address;
                
                if (axi_lite.arready) begin
                    next_state = LITE_RECEIVING_READ_DATA;
                end

                axi_lite.arvalid = 1'b1;
            end

            LITE_RECEIVING_READ_DATA: begin
                if (axi_lite.rvalid) begin
                    next_state = IDLE;
                    next_axi_lite_tx_done = 1'b1;
                    next_axi_lite_cached_addr = address;
                end

                axi_lite.rready = 1'b1;
            end
            
            default: begin
                $display("ERROR: Invalid cache FSM state");
            end
        endcase
    end

    // =======================
    // MISC SIGNALS
    // =======================

    // Byte enable mask generation
    wire [31:0] byte_enable_mask;
    assign byte_enable_mask = {
        {8{byte_enable[3]}},
        {8{byte_enable[2]}},
        {8{byte_enable[1]}},
        {8{byte_enable[0]}}
    };

    // AXI CONSTANTS

    // ADDRESS CHANNELS
    assign axi.awlen = WORDS_PER_LINE - 1;  // 16 words per burst
    assign axi.awsize = 3'b010;              // 4 bytes per transfer
    assign axi.awburst = 2'b01;              // INCR mode
    assign axi.arlen = WORDS_PER_LINE - 1;  // 16 words per burst
    assign axi.arsize = 3'b010;              // 4 bytes per transfer
    assign axi.arburst = 2'b01;              // INCR mode
    assign axi.awid = 4'b0000;
    assign axi.arid = 4'b0000;

    // DATA CHANNELS
    assign axi.wstrb = 4'b1111;              // Full word writes

endmodule
