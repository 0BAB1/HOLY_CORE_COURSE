/** INSTRUCTION CACHE MODULE - 2-Way Set Associative (Read-Only)
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : A 2-way set-associative instruction cache (read-only).
*                 Based on holy_data_cache, stripped down for instruction fetch.
*
*   Default Config is 256B as the memory is a raw async read buffer
*   which takes lots of resources, but do we really need more ?
*/

import holy_core_pkg::*;

module holy_instr_cache #(
    parameter WORDS_PER_LINE = 8,
    parameter NUM_SETS = 4,
    // MODIFYING THE FOLLOWING IS NOT SUPPORTED, SO PLEASE DONT
    parameter NUM_WAYS = 2
)(
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // CPU Interface
    input logic [31:0]  address,
    output logic [31:0] read_data,

    // Read handshake
    input logic         req_valid,
    output logic        req_ready,
    output logic        read_valid,
    input logic         read_ack,

    // AXI Interface for external requests
    axi_if.master axi,

    // State information for arbiter
    output cache_state_t cache_state
);

    // =======================
    // ADDRESS BREAKDOWN
    // =======================
    // Address format: [TAG | SET_INDEX | WORD_OFFSET | BYTE_OFFSET]
    
    localparam WAYS_BITS        = $clog2(NUM_WAYS);
    localparam BYTE_OFFSET_BITS = 2;
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    localparam SET_INDEX_BITS   = $clog2(NUM_SETS);
    localparam TAG_BITS         = 32 - BYTE_OFFSET_BITS - WORD_OFFSET_BITS - SET_INDEX_BITS;

    // Loop bounds (warning-free)
    localparam LAST_WORD = WORDS_PER_LINE - 1;
    localparam LAST_SET  = NUM_SETS - 1;

    wire [TAG_BITS-1:0]         req_tag;
    wire [SET_INDEX_BITS-1:0]   req_set;
    wire [WORD_OFFSET_BITS-1:0] req_word_offset;

    assign req_tag         = address[31:31-TAG_BITS+1];
    assign req_set         = address[BYTE_OFFSET_BITS+WORD_OFFSET_BITS +: SET_INDEX_BITS];
    assign req_word_offset = address[BYTE_OFFSET_BITS +: WORD_OFFSET_BITS];

    // =======================
    // CPU FRONTEND : HANDSHAKE CONTROL
    // =======================

    // Ready when idle
    assign req_ready = (state == IDLE);

    // Flag accepted request for state transition
    logic req_accepted;
    assign req_accepted = req_valid && req_ready;

    // Read valid signal when READ_OK (afte a miss) or when a hit happens in IDLE
    assign read_valid = (state == READ_OK) || (hit && req_accepted && state == IDLE);

    // Request latch on miss
    logic [31:0]                 pending_addr, next_pending_addr;
    logic [SET_INDEX_BITS-1:0]   pending_set, next_pending_set;
    logic [WORD_OFFSET_BITS-1:0] pending_word_offset, next_pending_word_offset;
    logic [TAG_BITS-1:0]         pending_tag, next_pending_tag;

    // =======================
    // CACHE STORAGE - SEPARATED WAYS FOR BRAM INFERENCE
    // =======================

    (* ram_style = "block" *) logic [31:0] cache_data_way0 [NUM_SETS-1:0][WORDS_PER_LINE-1:0];
    (* ram_style = "block" *) logic [31:0] cache_data_way1 [NUM_SETS-1:0][WORDS_PER_LINE-1:0];

    // Metadata
    logic [TAG_BITS-1:0] cache_tags  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic                cache_valid [NUM_WAYS-1:0][NUM_SETS-1:0];

    // LRU bits (1 bit per set)
    logic lru_bits [NUM_SETS-1:0];

    // =======================
    // HIT DETECTION
    // =======================

    logic hit_way0, hit_way1, hit;
    logic hit_way_select;
    logic victim_way;

    assign hit_way0 = cache_valid[0][req_set] && (cache_tags[0][req_set] == req_tag);
    assign hit_way1 = cache_valid[1][req_set] && (cache_tags[1][req_set] == req_tag);
    assign hit = hit_way0 || hit_way1;
    assign hit_way_select = hit_way1;  // 0 if way0 hits, 1 if way1 hits

    // Victim selection for replacement (use LRU)
    assign victim_way = lru_bits[req_set];

    // =======================
    // FSM STATE
    // =======================

    cache_state_t state, next_state;

    // Current way being serviced
    logic current_way, next_current_way;

    // Word pointer for burst transfers
    logic [WORD_OFFSET_BITS-1:0] word_ptr, next_word_ptr;

    // Cache metadata next state
    logic [TAG_BITS-1:0] next_cache_tags  [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic                next_cache_valid [NUM_WAYS-1:0][NUM_SETS-1:0];
    logic                next_lru_bits    [NUM_SETS-1:0];

    // =======================
    // BRAM PORT SIGNALS
    // =======================

    logic buffer_we_way0, buffer_we_way1;
    logic [SET_INDEX_BITS-1:0]   buffer_set_addr;
    logic [WORD_OFFSET_BITS-1:0] buffer_word_addr;
    logic [31:0] buffer_wdata;
    logic [31:0] buffer_rdata_way0, buffer_rdata_way1;

    // =======================
    // BRAM WRITE LOGIC
    // =======================

    always_ff @(posedge clk) begin
        if (buffer_we_way0) begin
            cache_data_way0[buffer_set_addr][buffer_word_addr] <= buffer_wdata;
        end
        if (buffer_we_way1) begin
            cache_data_way1[buffer_set_addr][buffer_word_addr] <= buffer_wdata;
        end
    end

    // BRAM read (combinational)
    assign buffer_rdata_way0 = cache_data_way0[buffer_set_addr][buffer_word_addr];
    assign buffer_rdata_way1 = cache_data_way1[buffer_set_addr][buffer_word_addr];

    // =======================
    // BRAM CONTROL SIGNALS
    // =======================

    always_comb begin
        // Defaults
        buffer_we_way0  = 1'b0;
        buffer_we_way1  = 1'b0;
        buffer_set_addr  = req_set;
        buffer_word_addr = req_word_offset;
        buffer_wdata     = axi.rdata;

        // AXI cache line fill
        if (state == RECEIVING_READ_DATA && axi.rvalid && axi.rready) begin
            buffer_set_addr  = pending_set;
            buffer_word_addr = word_ptr;
            buffer_wdata     = axi.rdata;
            buffer_we_way0   = (current_way == 1'b0);
            buffer_we_way1   = (current_way == 1'b1);
        end
        // Read address setup
        else if (state == IDLE || state == READ_OK) begin
            if (hit) begin
                buffer_set_addr  = req_set;
                buffer_word_addr = req_word_offset;
            end else begin
                buffer_set_addr  = pending_set;
                buffer_word_addr = pending_word_offset;
            end
        end
    end

    // =======================
    // MAIN SEQUENTIAL LOGIC (METADATA)
    // =======================

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            // Initialize all cache lines as invalid
            for (int w = 0; w < NUM_WAYS; w++) begin
                for (int s = 0; s < NUM_SETS; s++) begin
                    cache_valid[w][s] <= 1'b0;
                    cache_tags[w][s]  <= '0;
                end
            end

            // Initialize LRU bits
            for (int s = 0; s < NUM_SETS; s++) begin
                lru_bits[s] <= 1'b0;
            end

            // Pending request latches
            pending_addr        <= '0;
            pending_set         <= '0;
            pending_word_offset <= '0;
            pending_tag         <= '0;

        end else begin
            // Metadata updates
            cache_tags  <= next_cache_tags;
            cache_valid <= next_cache_valid;
            lru_bits    <= next_lru_bits;

            // Pending request latches
            pending_addr        <= next_pending_addr;
            pending_set         <= next_pending_set;
            pending_word_offset <= next_pending_word_offset;
            pending_tag         <= next_pending_tag;

            // Update LRU on read hit (when request is accepted)
            if (hit && req_accepted && state == IDLE) begin
                lru_bits[req_set] <= ~hit_way_select;
            end
        end
    end

    // =======================
    // FSM SEQUENTIAL LOGIC
    // =======================

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state       <= IDLE;
            word_ptr    <= '0;
            current_way <= 1'b0;
        end else begin
            state       <= next_state;
            word_ptr    <= next_word_ptr;
            current_way <= next_current_way;
        end
    end

    // =======================
    // FSM COMBINATIONAL LOGIC
    // =======================

    always_comb begin
        // Defaults
        next_state       = state;
        next_current_way = current_way;
        next_word_ptr    = word_ptr;

        // Cache metadata
        next_cache_tags  = cache_tags;
        next_cache_valid = cache_valid;
        next_lru_bits    = lru_bits;

        // Pending request latches
        next_pending_addr        = pending_addr;
        next_pending_set         = pending_set;
        next_pending_word_offset = pending_word_offset;
        next_pending_tag         = pending_tag;

        // AXI defaults (read-only, no write channels active)
        axi.arvalid = 1'b0;
        axi.rready  = 1'b0;
        axi.araddr  = 32'h0;

        // Write channels - permanently inactive
        axi.awvalid = 1'b0;
        axi.wvalid  = 1'b0;
        axi.wlast   = 1'b0;
        axi.bready  = 1'b0;
        axi.wdata   = '0;
        axi.awaddr  = 32'h0;

        // Outputs
        cache_state = state;
        read_data   = 32'h0;

        case (state)
            IDLE: begin
                // ACCEPT MISS READS
                if (req_accepted && ~hit) begin
                    next_current_way = victim_way;

                    // Latch request
                    next_pending_addr        = address;
                    next_pending_set         = req_set;
                    next_pending_word_offset = req_word_offset;
                    next_pending_tag         = req_tag;

                    // No dirty check needed - instruction cache is read-only
                    next_state    = SENDING_READ_REQ;
                    next_word_ptr = '0;
                end

                // ACCEPT HIT
                else if (hit && req_accepted) begin
                    read_data = hit_way_select ? cache_data_way1[req_set][req_word_offset]
                                               : cache_data_way0[req_set][req_word_offset];
                    // note: the valid is a comb assignement at file beginning
                end
            end

            SENDING_READ_REQ: begin
                axi.araddr  = {pending_tag, pending_set, {WORD_OFFSET_BITS{1'b0}}, 2'b00};
                axi.arvalid = 1'b1;

                if (axi.arready) begin
                    next_state    = RECEIVING_READ_DATA;
                    next_word_ptr = '0;
                end
            end

            RECEIVING_READ_DATA: begin
                axi.rready = 1'b1;

                if (axi.rvalid) begin
                    next_word_ptr = word_ptr + 1;

                    if (axi.rlast) begin
                        next_state = READ_OK;
                    end
                end
            end

            // READ OK ONLY AFTER A MISS
            READ_OK: begin
                // Output pending (missed) read data
                read_data = current_way ? cache_data_way1[pending_set][pending_word_offset]
                                        : cache_data_way0[pending_set][pending_word_offset];

                if (read_ack) begin
                    next_state = IDLE;
                    // Update cache metadata
                    next_cache_tags[current_way][pending_set]  = pending_tag;
                    next_cache_valid[current_way][pending_set] = 1'b1;
                    next_lru_bits[pending_set] = ~current_way;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // =======================
    // AXI CONSTANTS
    // =======================

    // Read address channel
    assign axi.arlen   = WORDS_PER_LINE - 1;
    assign axi.arsize  = 3'b010;  // 4 bytes per transfer
    assign axi.arburst = 2'b01;   // INCR mode
    assign axi.arid    = 4'b0000;

    // Write address channel (unused)
    assign axi.awlen   = '0;
    assign axi.awsize  = 3'b010;
    assign axi.awburst = 2'b01;
    assign axi.awid    = 4'b0000;

    // Write data channel (unused)
    assign axi.wstrb   = 4'b0000;

endmodule