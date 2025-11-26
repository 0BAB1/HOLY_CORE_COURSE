/** DATA CACHE MODULE
*
*   Author : BRH
*   Project : Holy Core Perf Edition
*   Description : A 2 way N sets, set-associative cache.
*                 Implementing AXI to request data from outside main memory.
*                 With a CPU handshake interface for OPTIMAL robusteness.
*                 The goal is to allow the user to connect its own memory on FPGA.
*                 It also supports non cachable ranges, which the use can set
*                 using CSRs.
*
*                 Goal is to implement cache as BRAM for optimal perfs
*                 Target : Xilinx FPGAs.
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
    input logic clk,
    input logic rst_n,

    // CPU Interface
    input logic [31:0]  address,
    input logic [31:0]  write_data,
    // handshake
    input logic         req_valid,
    output logic        req_ready,
    input logic         req_write, // 0->R // 1->W
    input logic [3:0]   byte_enable,
    // read out
    output logic [31:0] read_data,
    output logic        read_valid,
    input logic         read_ack,

    // incomming CSR Orders
    input logic         csr_flush_order,

    // AXI Interface for external requests
    axi_if.master axi,

    // State informations for arbitrer
    output cache_state_t cache_state
);
    // =======================
    // CPU FRONTEND : HANDSHAKE CONTROL
    // =======================

    // Ready when idle (and not flushing)
    assign req_ready = (state == IDLE) && ~(csr_flush_order && ~csr_flushing_done);
    
    // flag accepted request for state transition
    logic req_accepted;
    assign req_accepted = req_valid && req_ready;

    // Request latch on miss: in case of a miss, the cache needs to remember 
    // the original missed request to fulfill it once it has moved data around
    logic                       pending_write, next_pending_write;
    logic [31:0]                pending_addr, next_pending_addr;
    logic [31:0]                pending_data, next_pending_data;
    logic [31:0]                pending_be_mask, next_pending_be_mask;
    logic [SET_INDEX_BITS-1:0]  pending_set, next_pending_set;
    logic [WORD_OFFSET_BITS-1:0] pending_word_offset, next_pending_word_offset;
    logic [TAG_BITS-1:0]        pending_tag, next_pending_tag;

    assign read_valid = (state == READ_OK);

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
    (* ram_style = "block" *) logic [31:0]         cache_data  [NUM_WAYS-1:0][NUM_SETS-1:0][WORDS_PER_LINE-1:0];
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

    // =======================
    // HIT DETECTION COMB
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
    logic [TAG_BITS-1:0] next_cache_tags  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic next_cache_valid  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic next_cache_dirty  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic next_lru_bits     [NUM_SETS-1:0];
    
    // MAIN CLOCK DRIVEN SEQ LOGIC
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            csr_flushing <= 1'b0;
            csr_flushing_done <= 1'b0;
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

            // write miss latches
            pending_write <= 1'b0;
            pending_addr <= '0;
            pending_data <= '0;
            pending_be_mask <= '0;
            pending_set <= '0;
            pending_word_offset <= '0;
            pending_tag <= '0;
            
        end else begin
            // DEFAULT REG LATCHES
            // cache metadata
            cache_tags  <= next_cache_tags;
            cache_valid <= next_cache_valid;
            cache_dirty <= next_cache_dirty;
            lru_bits    <= next_lru_bits;
            
            csr_flushing <= next_csr_flushing;
            csr_flushing_done <= next_csr_flushing_done;

            // flush reg
            flush_way <= next_flush_way;
            flush_set <= next_flush_set;

            // pending request latches
            pending_write <= next_pending_write;
            pending_addr  <= next_pending_addr;
            pending_data <= next_pending_data;
            pending_be_mask <= next_pending_be_mask;
            pending_set <= next_pending_set;
            pending_word_offset <= next_pending_word_offset;
            pending_tag <= next_pending_tag;

            // Handle writes on cache hit (when request is accepted)
            if (hit && req_write && req_accepted && state == IDLE) begin
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
                cache_data[current_way][pending_set][word_ptr] <= axi.rdata;
            end

            // Fulfill pending write after cache line fill
            else if (state == FULFILL_PENDING_WRITE) begin
                cache_data[current_way][pending_set][pending_word_offset] <= 
                    (cache_data[current_way][pending_set][pending_word_offset] & ~pending_be_mask) | 
                    (pending_data & pending_be_mask);
            end
            
            // Update LRU on read hit (when request is accepted)
            if (hit && ~req_write && req_accepted && state == IDLE) begin
                lru_bits[req_set] <= ~hit_way_select;
            end
        end
    end

    // =======================
    // AXI FSM STATES
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
        next_current_way = current_way;
        next_word_ptr = word_ptr;
        
        // flush control
        next_csr_flushing = csr_flushing;
        next_csr_flushing_done = csr_flushing_done ? csr_flush_order : csr_flushing_done;
        next_flush_set = flush_set;
        next_flush_way = flush_way;
        
        // cache metadata
        next_cache_tags = cache_tags;
        next_cache_valid = cache_valid;
        next_cache_dirty = cache_dirty;
        next_lru_bits = lru_bits;
        
        // pending request latches
        next_pending_write = pending_write;
        next_pending_addr = pending_addr;
        next_pending_data = pending_data;
        next_pending_be_mask = pending_be_mask;
        next_pending_set = pending_set;
        next_pending_word_offset = pending_word_offset;
        next_pending_tag = pending_tag;

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

        case (state)
            IDLE: begin
                
                // INIT FLUSHING PROCEDURE
                if (csr_flush_order && ~csr_flushing_done) begin
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
                
                // ACCEPT MISS
                else if (req_accepted && ~hit) begin
                    // Cache miss on accepted request - determine victim way
                    next_current_way = victim_way;

                    // Latch the entire request for later fulfillment
                    next_pending_write = req_write;
                    next_pending_addr = address;
                    next_pending_data = write_data;
                    next_pending_be_mask = byte_enable_mask;
                    next_pending_set = req_set;
                    next_pending_word_offset = req_word_offset;
                    next_pending_tag = req_tag;
                    
                    // Check if victim line is dirty
                    if (cache_valid[victim_way][req_set] && cache_dirty[victim_way][req_set]) begin
                        next_state = SENDING_WRITE_REQ;
                    end else begin
                        next_state = SENDING_READ_REQ;
                    end
                    next_word_ptr = '0;
                end
                
                // ACCEPT HIT (READ)
                else if (hit && ~req_write && req_accepted) begin
                    next_state = READ_OK;
                end
            end
            
            SENDING_WRITE_REQ: begin
                // Write back dirty cache line
                if (csr_flushing) begin
                    axi.awaddr = {cache_tags[flush_way][flush_set], flush_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                end else begin
                    axi.awaddr = {cache_tags[current_way][pending_set], pending_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
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
                    axi.wdata = cache_data[current_way][pending_set][word_ptr];
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
                        
                        // Flushing implies flushing all sets from all ways
                        // so we increment flush set / way pointers
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

                                if (cache_valid[next_flush_way][next_flush_set]) begin
                                    next_state = SENDING_WRITE_REQ;
                                end else begin
                                    next_state = FLUSH_NEXT;
                                end
                            end
                        end else begin
                            // next set in same way
                            next_flush_set = flush_set + 1'b1;
                            if (cache_valid[next_flush_way][next_flush_set]) begin
                                next_state = SENDING_WRITE_REQ;
                            end else begin
                                next_state = FLUSH_NEXT;
                            end
                        end

                    end else begin
                        // Normal write-back complete, now fetch the data
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
                
                // Check if next set needs flushing
                if (cache_valid[next_flush_way][next_flush_set]) begin
                    next_state = SENDING_WRITE_REQ;
                end else if ((flush_way != 1'b1) && (flush_set) != 3'b111) begin
                    next_state = FLUSH_NEXT;
                end
            end

            SENDING_READ_REQ: begin
                axi.araddr = {pending_tag, pending_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                
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
                        // Depending on what caused the miss, we react differently
                        if(pending_write) begin
                            next_state = FULFILL_PENDING_WRITE;
                        end else begin
                            next_state = READ_OK;
                            next_cache_dirty[current_way][pending_set] = 1'b0;
                        end
                    end
                end

                axi.rready = 1'b1;
            end

            READ_OK: begin
                // Signal output data as valid
                if(read_ack) begin
                    next_state = IDLE;
                    // Update cache metadata
                    next_cache_tags[current_way][pending_set] = pending_tag;
                    next_cache_valid[current_way][pending_set] = 1'b1;
                    next_lru_bits[pending_set] = ~current_way;
                end
                
                // Set read data
                if(hit) begin
                    read_data = cache_data[hit_way_select][req_set][req_word_offset];
                end else begin
                    read_data = cache_data[current_way][pending_set][pending_word_offset];
                end
                
            end

            FULFILL_PENDING_WRITE : begin
                // The miss was caused by a write
                // SEQ logic will write the data when this state is active
                next_pending_write = 1'b0;
                next_state = IDLE;
                
                // Update cache metadata for the write
                next_cache_tags[current_way][pending_set] = pending_tag;
                next_cache_dirty[current_way][pending_set] = 1'b1;
                next_cache_valid[current_way][pending_set] = 1'b1;
                next_lru_bits[pending_set] = ~current_way;
            end
            
            default: begin
                $display("ERROR: Invalid cache FSM state");
            end
        endcase
    end

    // =======================
    // MISC SIGNALS
    // =======================

    // Byte enable mask generation (for current request)
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