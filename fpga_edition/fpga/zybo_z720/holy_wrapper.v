module holy_wrapper (
    input wire clk,
    input wire rst_n,
    input wire aclk,
    input wire aresetn,
    output wire [3:0]               m_axi_awid,
    output wire [31:0]              m_axi_awaddr,
    output wire [7:0]               m_axi_awlen,
    output wire [2:0]               m_axi_awsize,
    output wire [1:0]               m_axi_awburst,
    output wire                     m_axi_awvalid,
    input  wire                     m_axi_awready,
    output wire [31:0]              m_axi_wdata, 
    output wire [3:0]               m_axi_wstrb,
    output wire                     m_axi_wlast,
    output wire                     m_axi_wvalid,
    input  wire                     m_axi_wready,
    input  wire [3:0]               m_axi_bid,
    input  wire [1:0]               m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output wire                     m_axi_bready,
    output wire [3:0]               m_axi_arid,
    output wire [31:0]              m_axi_araddr,
    output wire [7:0]               m_axi_arlen,
    output wire [2:0]               m_axi_arsize,
    output wire [1:0]               m_axi_arburst,
    output wire                     m_axi_arvalid,
    input  wire                     m_axi_arready,
    input  wire [3:0]               m_axi_rid,
    input  wire [31:0]              m_axi_rdata,
    input  wire [1:0]               m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output wire                     m_axi_rready,

    // Debug OUT
    output wire [31:0]              pc,
    output wire [31:0]              pc_next,
    output wire [31:0]              instruction,
    output wire [2:0]               i_cache_state,
    output wire [2:0]               d_cache_state,
    output wire                     i_cache_stall,
    output wire                     d_cache_stall,
    output wire [6:0]               i_cache_set_ptr,
    output wire [6:0]               d_cache_set_ptr,
    output wire [6:0]               i_next_set_ptr,
    output wire [6:0]               d_next_set_ptr
);

// Explicit interface wires
wire aclk;
wire aresetn;
wire clk;
wire rst_n;
wire [3:0]  m_axi_awid;
wire [31:0] m_axi_awaddr;
wire [7:0]  m_axi_awlen;
wire [2:0]  m_axi_awsize;
wire [1:0]  m_axi_awburst;
wire        m_axi_awvalid;
wire        m_axi_awready;
wire [31:0] m_axi_wdata;
wire [3:0]  m_axi_wstrb;
wire        m_axi_wlast;
wire        m_axi_wvalid;
wire        m_axi_wready;
wire [3:0]  m_axi_bid;
wire [1:0]  m_axi_bresp;
wire        m_axi_bvalid;
wire        m_axi_bready;
wire [3:0]  m_axi_arid;
wire [31:0] m_axi_araddr;
wire [7:0]  m_axi_arlen;
wire [2:0]  m_axi_arsize;
wire [1:0]  m_axi_arburst;
wire        m_axi_arvalid;
wire        m_axi_arready;
wire [3:0]  m_axi_rid;
wire [31:0] m_axi_rdata;
wire [1:0]  m_axi_rresp;
wire        m_axi_rlast;
wire        m_axi_rvalid;
wire        m_axi_rready;
// Debug signal wires
wire [31:0] pc;
wire [31:0] pc_d;
wire [31:0] instruction;
wire [2:0]  i_cache_state;
wire [2:0]  d_cache_state;
wire        i_cache_stall;
wire        d_cache_stall;
wire [6:0]  i_cache_set_ptr;
wire [6:0]  d_cache_set_ptr;
wire [6:0]  i_next_set_ptr;
wire [6:0]  d_next_set_ptr;

// Explicit connection to holy_test_harness module
axi_details wrapped (
    // GENERIC SIGNALS
    .clk(clk),
    .rst_n(rst_n),
    // AXI SIGNALS
    .aclk(aclk),
    .aresetn(aresetn),
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr), 
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata), 
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),
    // DEBUG SIGNALS
    .pc(pc),  
    .pc_next(pc_next),  
    .instruction(instruction),  
    .i_cache_state(i_cache_state),  
    .d_cache_state(d_cache_state),
    .i_cache_set_ptr(i_cache_set_ptr),  
    .d_cache_set_ptr(d_cache_set_ptr),  
    .i_cache_stall(i_cache_stall),  
    .i_next_set_ptr(i_next_set_ptr),
    .d_cache_stall(d_cache_stall),
    .d_next_set_ptr(d_next_set_ptr)
);

endmodule
