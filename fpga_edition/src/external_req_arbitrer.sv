/** External AXI requests arbitrer MODULE
*
*   Author : BABIN-RIBY Hugo
*   Project : Holy Core V2
*   Description : A simple arbitrer that muxes incomming
*   AXI requests from data and instruction caches to a single AXI
*   interface.
*/

import holy_core_pkg::*;

module external_req_arbitrer (
    // Master outgoing interface
    axi_if.master m_axi,

    // SLAVE axi ifs for I$ and D$
    axi_if.slave s_axi_instr,
    input cache_state_t i_cache_state,
    axi_if.slave s_axi_data,
    input cache_state_t d_cache_state
);

// The request controller simply muxes the transactions until they are done using state info from the caches

always_comb begin : main_axi_mux
    // Default values for master AXI signals, all 0. franckly we don't care about them.
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

    if (i_cache_state != IDLE) begin
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
    
    end else if (d_cache_state != IDLE) begin
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