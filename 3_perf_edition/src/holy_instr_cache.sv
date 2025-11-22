/** CACHE MODULE
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : A 1 way direct mapped cache.
*                 Implementing AXI to request data from outside main memory.
*                 With a CPU interface for basic core request with stall signal.
*                 The goal is to allow the user to connect its own memory on FPGA.
*                 It also supports non cachable ranges, which the use can set
*                 using CSRs.
*
*   Created 11/24
*   Modifications: 05/25 Add manual flush support (BRH)
*                  06/25 Add non cachable range support (BRH)
*/

import holy_core_pkg::*;

module holy_instr_cache #(
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
    output logic [31:0] read_data,
    output logic        cache_stall,
    output logic        instr_valid,

    // incomming CSR Orders
    input logic         csr_flush_order,
    input logic [31:0] non_cachable_base,
    input logic [31:0] non_cachable_limit,

    // AXI Interface for external requests
    axi_if.master axi,

    // AXI LITE Interface for external requests
    axi_lite_if.master axi_lite,

    // State informations for arbitrer
    output cache_state_t cache_state,

    // debug signals
    output logic [6:0] set_ptr_out,
    output logic [6:0] next_set_ptr_out,
    output logic       debug_seq_stall,
    output logic       debug_comb_stall,
    output logic [3:0] debug_next_cache_state
);

    // Here is how a cache line is organized:
    // | DIRTY | VALID | BLOCK TAG | INDEX/SET | OFFSET | DATA |
    // | FLAGS         | ADDRESS INFOS                  | DATA |

    // CACHE TABLE DECLARATION
    logic [CACHE_SIZE-1:0][31:0]    cache_data;
    logic [31:9]                    cache_block_tag;    // direct mapped cache so only one block, only one tag
    logic                           cache_valid, next_cache_valid;        // is the current block valid ?
    logic                           cache_dirty;
    // register to retain info on wether we are writing back because of miss or because of CSR order
    logic                           csr_flushing, next_csr_flushing;
    // non_cashable ? is the reaquested address *NOT* cachable
    // WARNING : because the cache works by block, only the TAG from the addresses is taken in cosideration to determine cachability.
    // meaning the end user (dev) has to be aware that low range resolution eg 0x00000000 to 0x000000000F will not be considered.
    logic                           non_cachable;
    assign non_cachable = ((req_block_tag >= non_cachable_base[31:9]) && (req_block_tag < non_cachable_limit[31:9]));

    logic [31:0]                    axi_lite_read_result; // axi lite's only data reg for non cachable data
    // IMPORTANT : axi_lite_tx_done is flag used to determinen if R or W tx has been completed
    // it is set to 1 after a successful AXI LITE TX to avoid going into a NON IDLE state right away
    // and let the core fetch a new instruction.
    // This also means it stays high for 1 clock cycle only before going low again, thus allwing the cache
    // to go NON-IDLE again on the non cachable range.
    logic                           axi_lite_tx_done, next_axi_lite_tx_done;
    // we also remember the axi lite pulled addr so axi lite tx bahaves like a single
    // scratchpas cache. (even though its for "non cachable" stuff)
    logic [31:0]                    axi_lite_cached_addr, next_axi_lite_cached_addr;

    // INCOMING CACHE REQUEST SIGNALS
    logic [31:9]                    req_block_tag;
    assign req_block_tag = address[31:9];
    // requested place in cache, written / read if tag hits
    logic [8:2] req_index;
    assign req_index = address[8:2];

    // HIT LOGIC
    logic hit;
    assign hit = ((req_block_tag == cache_block_tag) && cache_valid) | non_cachable;

    // STALL LOGIC
    logic actual_write_enable;
    assign actual_write_enable = write_enable & |byte_enable;
    logic comb_stall, seq_stall;
    assign comb_stall = (next_state != IDLE) | (~hit & (read_enable | actual_write_enable));
    assign cache_stall = (comb_stall | seq_stall) && ~axi_lite_tx_done;

    // Instruction valid flagging
    assign instr_valid = non_cachable ? ~cache_stall : (cache_valid && next_cache_valid);

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
            axi_lite_tx_done <= 1'b0;
            // 1 is never valid on startup
            axi_lite_cached_addr <= 32'h00000001;
        end else begin
            cache_valid <= next_cache_valid;
            seq_stall <= comb_stall;

            if(hit && write_enable & state == IDLE) begin
                cache_data[req_index] <= (cache_data[req_index] & ~byte_enable_mask) | (write_data & byte_enable_mask);
                cache_dirty <= 1'b1;
            end else if(axi.rvalid & state == RECEIVING_READ_DATA & axi.rready) begin
                // Write incomming axi reads
                cache_data[set_ptr] <= axi.rdata;
                if(axi.rready & axi.rlast) begin
                    cache_block_tag <= req_block_tag;
                    cache_dirty <= 1'b0;
                end
            end else if(axi_lite.rvalid & state == LITE_RECEIVING_READ_DATA & axi_lite.rready) begin
                // Write incomming axi lite read
                axi_lite_read_result <= axi_lite.rdata;
            end

            csr_flushing <= next_csr_flushing;
            axi_lite_tx_done <= next_axi_lite_tx_done;
            axi_lite_cached_addr <= next_axi_lite_cached_addr;
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

    // =======================
    // READ & MAIN FSM LOGIC
    // =======================
    always_comb begin
        // State transition 
        next_state = state; // Default
        next_cache_valid =  hit ? cache_valid : 0; // cache is valid as long as we hit
        next_axi_lite_tx_done = axi_lite_tx_done;
        next_axi_lite_cached_addr = axi_lite_cached_addr;
        if(!read_enable && !write_enable) next_axi_lite_cached_addr = 32'd1; // unvalidate the axi result after request is fulfilled

        // AXI LITE DEFAULT
        axi_lite.wstrb = 4'b1111; // we write all by default.
        axi_lite.wdata   = write_data;
        axi_lite.arvalid = 0;
        axi_lite.awvalid = 0;
        axi_lite.wvalid  = 0;
        axi_lite.bready  = 0;
        axi_lite.rready  = 0;

        // AXI DEFAULT
        axi.wlast   = 0;
        axi.arvalid = 0;
        axi.awvalid = 0;
        axi.wvalid  = 0;
        axi.bready  = 0;
        axi.rready  = 0;

        // WDATA OUT
        axi.wdata = cache_data[set_ptr];
        cache_state = state;
        next_set_ptr = set_ptr;

        // MISC CACHE CONTROL
        next_csr_flushing = csr_flushing;

        case (state)
            IDLE: begin
                // when idling, we simply read and write, no problem !
                // but let's be carefull and notif in case of error (no traps yet to handle that)
                if(read_enable && write_enable) $display("ERROR, CAN'T READ AND WRITE AT THE SAME TIME!!!");

                else if(csr_flush_order) begin
                    // don't forget to keep in mind that we are flushing from order
                    // which will bypass reading back
                    next_csr_flushing = 1'b1;
                    // also, we force write back state next
                    next_state = SENDING_WRITE_REQ;
                end

                else if( (~hit && (read_enable ^ actual_write_enable)) & ~csr_flush_order & ~non_cachable) begin
                    // switch state to handle the MISS, if data is dirty, we have to write first
                    case(cache_dirty)
                        1'b1 : next_state = SENDING_WRITE_REQ;
                        1'b0 : next_state = SENDING_READ_REQ;
                    endcase
                end
                
                else if ( read_enable & non_cachable & ~axi_lite_tx_done ) begin
                    if(axi_lite_cached_addr != address)begin
                        next_state = LITE_SENDING_READ_REQ;
                    end
                end

                else if ( write_enable & non_cachable & ~axi_lite_tx_done ) begin
                    next_state = LITE_SENDING_WRITE_REQ;
                end

                // READ DATA OUT COMB LOGIC AND SOURCE MUX (cachable or not ?)
                read_data = cache_data[req_index];
                if(hit && read_enable && ~non_cachable) begin
                    // async reads
                    read_data = cache_data[req_index];
                end else if ( non_cachable && read_enable ) begin
                    read_data = axi_lite_read_result;
                end

                // -----------------------------------
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
                    $display("ERROR WRTING TO MAIN MEMORY !");
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
                // HANDLE MISS : Read
                axi_lite.araddr = address;
                
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
                    next_axi_lite_cached_addr = address;
                end
            
                // AXI LITE Signals
                axi_lite.awvalid = 1'b0;
                axi_lite.wvalid = 1'b0;
                axi_lite.bready = 1'b0;
                axi_lite.arvalid = 1'b0;
                axi_lite.rready = 1'b1;
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

    // misc debug assignements
    assign set_ptr_out = set_ptr;
    assign next_set_ptr_out = next_set_ptr;
    assign debug_seq_stall = seq_stall;
    assign debug_comb_stall = comb_stall;
    assign debug_next_cache_state = next_state;
endmodule
