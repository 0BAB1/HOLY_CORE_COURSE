/** External AXI requests arbitrer (WITH TRANSACTION LOCKING)
*
*   Author : BRH
*   Project : Holy Core V2
*   Description : A simple arbitrer that muxes incoming
*                 AXI requests from data and instruction caches to a single AXI
*                 interface (just a big mux).
*
*   CRITICAL FIX: Added transaction locking to prevent switching masters
*                 mid-transaction. Once a cache starts a transaction, it owns
*                 the bus until completion.
*/
import holy_core_pkg::*;

(* DONT_TOUCH = "TRUE" *)
module external_req_arbitrer (
    input logic clk,
    input logic rst_n,
    
    // Master outgoing interface
    axi_if.master m_axi,

    // SLAVE axi ifs for I$ and D$
    axi_if.slave s_axi_instr,
    input cache_state_t i_cache_state,
    axi_if.slave s_axi_data,
    input cache_state_t d_cache_state
);

// ============================================================================
// TRANSACTION LOCKING
// ============================================================================
// Lock to current master once transaction starts, release when complete

serving_state_t serving, next_serving;

// Detect active transactions
logic i_cache_requesting;
logic d_cache_requesting;

assign i_cache_requesting = i_cache_state != IDLE && i_cache_state != READ_OK;
assign d_cache_requesting = d_cache_state != IDLE && d_cache_state != READ_OK;

// Lock state machine
always_ff @(posedge clk) begin
    if (~rst_n) begin
        serving <= SERVING_NONE;
    end else begin
        serving <= next_serving;
    end
end

// Determine who to serve and when to lock/unlock
always_comb begin
    next_serving = serving;
    
    case (serving)
        SERVING_NONE: begin
            // No one is being served - arbitrate
            if (i_cache_requesting) begin
                next_serving = SERVING_INSTR;
            end else if (d_cache_requesting) begin
                next_serving = SERVING_DATA;
            end
        end
        
        SERVING_INSTR: begin
            // Keep serving instruction cache until it goes IDLE
            if (!i_cache_requesting) begin
                next_serving = SERVING_NONE;
            end
        end
        
        SERVING_DATA: begin
            // Keep serving data cache until it goes IDLE
            if (!d_cache_requesting) begin
                next_serving = SERVING_NONE;
            end
        end

        default: ;
    endcase
end

// ============================================================================
// AXI MUX BASED ON LOCKED STATE
// ============================================================================

always_comb begin : main_axi_mux
    // ====================================
    // DEFAULT: All outputs to 0
    // ====================================
    m_axi.awid = 0;
    m_axi.awaddr = 0;
    m_axi.awlen = 0;
    m_axi.awsize = 0;
    m_axi.awburst = 0;
    m_axi.awvalid = 0;
    m_axi.wdata = 0;
    m_axi.wstrb = 0;
    m_axi.wlast = 0;
    m_axi.wvalid = 0;
    m_axi.bready = 0;
    m_axi.arid = 0;
    m_axi.araddr = 0;
    m_axi.arlen = 0;
    m_axi.arsize = 0;
    m_axi.arburst = 0;
    m_axi.arvalid = 0;
    m_axi.rready = 0;

    s_axi_instr.awready = 0;
    s_axi_instr.wready = 0;
    s_axi_instr.bid    = 0;
    s_axi_instr.bresp  = 0;
    s_axi_instr.bvalid = 0;
    s_axi_instr.arready = 0;
    s_axi_instr.rid    = 0;
    s_axi_instr.rdata  = 0;
    s_axi_instr.rresp  = 0;
    s_axi_instr.rlast  = 0;
    s_axi_instr.rvalid = 0;
    
    s_axi_data.awready = 0;
    s_axi_data.wready = 0;
    s_axi_data.bid    = 0;
    s_axi_data.bresp  = 0;
    s_axi_data.bvalid = 0;
    s_axi_data.arready = 0;
    s_axi_data.rid    = 0;
    s_axi_data.rdata  = 0;
    s_axi_data.rresp  = 0;
    s_axi_data.rlast  = 0;
    s_axi_data.rvalid = 0;

    // ====================================
    // ROUTE BASED ON LOCKED STATE
    // ====================================
    
    if (serving == SERVING_INSTR || next_serving == SERVING_INSTR) begin
        // ================
        // ROUTE I-CACHE
        // ================
        
        // Write Address Channel
        m_axi.awid     = s_axi_instr.awid;
        m_axi.awaddr   = s_axi_instr.awaddr;
        m_axi.awlen    = s_axi_instr.awlen;
        m_axi.awsize   = s_axi_instr.awsize;
        m_axi.awburst  = s_axi_instr.awburst;
        m_axi.awvalid  = s_axi_instr.awvalid;
        s_axi_instr.awready = m_axi.awready;
    
        // Write Data Channel
        m_axi.wdata    = s_axi_instr.wdata;
        m_axi.wstrb    = s_axi_instr.wstrb;
        m_axi.wlast    = s_axi_instr.wlast;
        m_axi.wvalid   = s_axi_instr.wvalid;
        s_axi_instr.wready = m_axi.wready;
    
        // Write Response Channel
        s_axi_instr.bid    = m_axi.bid;
        s_axi_instr.bresp  = m_axi.bresp;
        s_axi_instr.bvalid = m_axi.bvalid;
        m_axi.bready       = s_axi_instr.bready;
    
        // Read Address Channel
        m_axi.arid     = s_axi_instr.arid;
        m_axi.araddr   = s_axi_instr.araddr;
        m_axi.arlen    = s_axi_instr.arlen;
        m_axi.arsize   = s_axi_instr.arsize;
        m_axi.arburst  = s_axi_instr.arburst;
        m_axi.arvalid  = s_axi_instr.arvalid;
        s_axi_instr.arready = m_axi.arready;
    
        // Read Data Channel
        s_axi_instr.rid    = m_axi.rid;
        s_axi_instr.rdata  = m_axi.rdata;
        s_axi_instr.rresp  = m_axi.rresp;
        s_axi_instr.rlast  = m_axi.rlast;
        s_axi_instr.rvalid = m_axi.rvalid;
        m_axi.rready       = s_axi_instr.rready;
    
    end else if (serving == SERVING_DATA || next_serving == SERVING_DATA) begin
        // ================
        // ROUTE D-CACHE
        // ================
        
        // Write Address Channel
        m_axi.awid     = s_axi_data.awid;
        m_axi.awaddr   = s_axi_data.awaddr;
        m_axi.awlen    = s_axi_data.awlen;
        m_axi.awsize   = s_axi_data.awsize;
        m_axi.awburst  = s_axi_data.awburst;
        m_axi.awvalid  = s_axi_data.awvalid;
        s_axi_data.awready = m_axi.awready;
    
        // Write Data Channel
        m_axi.wdata    = s_axi_data.wdata;
        m_axi.wstrb    = s_axi_data.wstrb;
        m_axi.wlast    = s_axi_data.wlast;
        m_axi.wvalid   = s_axi_data.wvalid;
        s_axi_data.wready = m_axi.wready;
    
        // Write Response Channel
        s_axi_data.bid    = m_axi.bid;
        s_axi_data.bresp  = m_axi.bresp;
        s_axi_data.bvalid = m_axi.bvalid;
        m_axi.bready      = s_axi_data.bready;
    
        // Read Address Channel
        m_axi.arid     = s_axi_data.arid;
        m_axi.araddr   = s_axi_data.araddr;
        m_axi.arlen    = s_axi_data.arlen;
        m_axi.arsize   = s_axi_data.arsize;
        m_axi.arburst  = s_axi_data.arburst;
        m_axi.arvalid  = s_axi_data.arvalid;
        s_axi_data.arready = m_axi.arready;
    
        // Read Data Channel
        s_axi_data.rid    = m_axi.rid;
        s_axi_data.rdata  = m_axi.rdata;
        s_axi_data.rresp  = m_axi.rresp;
        s_axi_data.rlast  = m_axi.rlast;
        s_axi_data.rvalid = m_axi.rvalid;
        m_axi.rready      = s_axi_data.rready;
    end
end
    
endmodule

// ============================================================================
// AXI LITE ARBITER (WITH TRANSACTION LOCKING)
// ============================================================================

module external_req_arbitrer_lite (
    input logic clk,
    input logic rst_n,
    
    // Master outgoing interface
    axi_lite_if.master m_axi_lite,

    // SLAVE axi ifs for I$ and D$
    axi_lite_if.slave s_axi_lite_instr,
    input cache_state_t i_cache_state,
    axi_lite_if.slave s_axi_lite_data,
    input cache_state_t d_cache_state
);

// ============================================================================
// TRANSACTION LOCKING
// ============================================================================

serving_state_t serving, next_serving;

logic i_cache_requesting;
logic d_cache_requesting;

assign i_cache_requesting = i_cache_state != IDLE && i_cache_state != READ_OK;
assign d_cache_requesting = d_cache_state != IDLE && d_cache_state != READ_OK;

always_ff @(posedge clk) begin
    if (~rst_n) begin
        serving <= SERVING_NONE;
    end else begin
        serving <= next_serving;
    end
end

always_comb begin
    next_serving = serving;
    
    case (serving)
        SERVING_NONE: begin
            if (i_cache_requesting) begin
                next_serving = SERVING_INSTR;
            end else if (d_cache_requesting) begin
                next_serving = SERVING_DATA;
            end
        end
        
        SERVING_INSTR: begin
            if (!i_cache_requesting) begin
                next_serving = SERVING_NONE;
            end
        end
        
        SERVING_DATA: begin
            if (!d_cache_requesting) begin
                next_serving = SERVING_NONE;
            end
        end

        default:;
    endcase
end

// ============================================================================
// AXI LITE MUX
// ============================================================================

always_comb begin : main_axi_lite_mux
    // Defaults
    m_axi_lite.awaddr = 0;
    m_axi_lite.awvalid = 0;
    m_axi_lite.wdata = 0;
    m_axi_lite.wstrb = 0;
    m_axi_lite.wvalid = 0;
    m_axi_lite.bready = 0;
    m_axi_lite.araddr = 0;
    m_axi_lite.arvalid = 0;
    m_axi_lite.rready = 0;

    s_axi_lite_instr.awready = 0;
    s_axi_lite_instr.wready = 0;
    s_axi_lite_instr.bresp  = 0;
    s_axi_lite_instr.bvalid = 0;
    s_axi_lite_instr.arready = 0;
    s_axi_lite_instr.rdata  = 0;
    s_axi_lite_instr.rresp  = 0;
    s_axi_lite_instr.rvalid = 0;
    
    s_axi_lite_data.awready = 0;
    s_axi_lite_data.wready = 0;
    s_axi_lite_data.bresp  = 0;
    s_axi_lite_data.bvalid = 0;
    s_axi_lite_data.arready = 0;
    s_axi_lite_data.rdata  = 0;
    s_axi_lite_data.rresp  = 0;
    s_axi_lite_data.rvalid = 0;

    if (serving == SERVING_INSTR || next_serving == SERVING_INSTR) begin
        // Route I-cache
        m_axi_lite.awaddr = s_axi_lite_instr.awaddr;
        m_axi_lite.awvalid = s_axi_lite_instr.awvalid;
        s_axi_lite_instr.awready = m_axi_lite.awready;
    
        m_axi_lite.wdata = s_axi_lite_instr.wdata;
        m_axi_lite.wstrb = s_axi_lite_instr.wstrb;
        m_axi_lite.wvalid = s_axi_lite_instr.wvalid;
        s_axi_lite_instr.wready = m_axi_lite.wready;
    
        s_axi_lite_instr.bresp = m_axi_lite.bresp;
        s_axi_lite_instr.bvalid = m_axi_lite.bvalid;
        m_axi_lite.bready = s_axi_lite_instr.bready;
    
        m_axi_lite.araddr = s_axi_lite_instr.araddr;
        m_axi_lite.arvalid = s_axi_lite_instr.arvalid;
        s_axi_lite_instr.arready = m_axi_lite.arready;
    
        s_axi_lite_instr.rdata = m_axi_lite.rdata;
        s_axi_lite_instr.rresp = m_axi_lite.rresp;
        s_axi_lite_instr.rvalid = m_axi_lite.rvalid;
        m_axi_lite.rready = s_axi_lite_instr.rready;
    
    end else if (serving == SERVING_DATA || next_serving == SERVING_DATA) begin
        // Route D-cache
        m_axi_lite.awaddr = s_axi_lite_data.awaddr;
        m_axi_lite.awvalid = s_axi_lite_data.awvalid;
        s_axi_lite_data.awready = m_axi_lite.awready;
    
        m_axi_lite.wdata = s_axi_lite_data.wdata;
        m_axi_lite.wstrb = s_axi_lite_data.wstrb;
        m_axi_lite.wvalid = s_axi_lite_data.wvalid;
        s_axi_lite_data.wready = m_axi_lite.wready;
    
        s_axi_lite_data.bresp = m_axi_lite.bresp;
        s_axi_lite_data.bvalid = m_axi_lite.bvalid;
        m_axi_lite.bready = s_axi_lite_data.bready;
    
        m_axi_lite.araddr = s_axi_lite_data.araddr;
        m_axi_lite.arvalid = s_axi_lite_data.arvalid;
        s_axi_lite_data.arready = m_axi_lite.arready;
    
        s_axi_lite_data.rdata = m_axi_lite.rdata;
        s_axi_lite_data.rresp = m_axi_lite.rresp;
        s_axi_lite_data.rvalid = m_axi_lite.rvalid;
        m_axi_lite.rready = s_axi_lite_data.rready;
    end
end
    
endmodule