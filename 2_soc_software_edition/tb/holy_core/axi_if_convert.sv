/** axi_if_convert
*
*   Author : BABIN-RIBY Hugo
*
*   Description : Utils to convert AXI signals from 1 definition
*                 to another. e.g. from an vedor AXI if to holy
*                 core's axi if. These utils are just passthoughs.
*
*   BRH 07/25
*/

module hc_axil_pulp_axil_passthrough (
    axi_lite_if.slave in_if,
    AXI_LITE.Master out_if
);
  // AW channel
  assign out_if.aw_addr  = in_if.awaddr;
  assign out_if.aw_valid = in_if.awvalid;
  assign in_if.awready   = out_if.aw_ready;
  assign out_if.aw_prot  = '0;

  // W channel
  assign out_if.w_data   = in_if.wdata;
  assign out_if.w_strb   = in_if.wstrb;
  assign out_if.w_valid  = in_if.wvalid;
  assign in_if.wready    = out_if.w_ready;

  // B channel
  assign in_if.bresp     = out_if.b_resp;
  assign in_if.bvalid    = out_if.b_valid;
  assign out_if.b_ready  = in_if.bready;

  // AR channel
  assign out_if.ar_addr  = in_if.araddr;
  assign out_if.ar_valid = in_if.arvalid;
  assign in_if.arready   = out_if.ar_ready;
  assign out_if.ar_prot  = '0;

  // R channel
  assign in_if.rdata     = out_if.r_data;
  assign in_if.rresp     = out_if.r_resp;
  assign in_if.rvalid    = out_if.r_valid;
  assign out_if.r_ready  = in_if.rready;

endmodule

module pulp_axil_hc_axil_passthrough (
    AXI_LITE.Slave in_if,
    axi_lite_if.master out_if
);
    // AW channel
    assign out_if.awaddr = in_if.aw_addr;
    assign out_if.awvalid = in_if.aw_valid;
    assign in_if.aw_ready = out_if.awready;

    // W channel
    assign out_if.wdata = in_if.w_data;
    assign out_if.wstrb = in_if.w_strb;
    assign out_if.wvalid = in_if.w_valid;
    assign in_if.w_ready = out_if.wready;

    // B channel
    assign in_if.b_resp = out_if.bresp;
    assign in_if.b_valid = out_if.bvalid;
    assign out_if.bready = in_if.b_ready;

    // AR channel
    assign out_if.araddr = in_if.ar_addr;
    assign out_if.arvalid = in_if.ar_valid;
    assign in_if.ar_ready = out_if.arready;

    // R channel
    assign in_if.r_data = out_if.rdata;
    assign in_if.r_resp = out_if.rresp;
    assign in_if.r_valid = out_if.rvalid;
    assign out_if.rready = in_if.r_ready;

endmodule

module hc_axi_pulp_axi_passthrough (
    axi_if.slave in_if,
    AXI_BUS.Master out_if
);
  // AW channel
  assign out_if.aw_id  = in_if.awid;
  assign out_if.aw_addr  = in_if.awaddr;
  assign out_if.aw_len = in_if.awlen;
  assign out_if.aw_size = in_if.awsize;
  assign out_if.aw_burst = in_if.awburst;
  assign out_if.aw_qos = in_if.awqos;
  assign out_if.aw_lock = in_if.awlock;
  assign out_if.aw_valid = in_if.awvalid;
  assign in_if.awready   = out_if.aw_ready;
  assign out_if.aw_prot  = '0;

  // W channel
  assign out_if.w_data   = in_if.wdata;
  assign out_if.w_strb   = in_if.wstrb;
  assign out_if.w_last  = in_if.wlast;
  assign out_if.w_valid  = in_if.wvalid;
  assign in_if.wready    = out_if.w_ready;

  // B channel
  assign in_if.bid     = out_if.b_id;
  assign in_if.bresp     = out_if.b_resp;
  assign in_if.bvalid    = out_if.b_valid;
  assign out_if.b_ready  = in_if.bready;

  // AR channel
  assign out_if.ar_id  = in_if.arid;
  assign out_if.ar_addr  = in_if.araddr;
  assign out_if.ar_len = in_if.arlen;
  assign out_if.ar_size = in_if.arsize;
  assign out_if.ar_burst = in_if.arburst;
  assign out_if.ar_qos = in_if.arqos;
  assign out_if.ar_lock = in_if.arlock;
  assign out_if.ar_valid = in_if.arvalid;
  assign in_if.arready   = out_if.ar_ready;
  assign out_if.ar_prot  = '0;

  // R channel
  assign in_if.rid     = out_if.r_id;
  assign in_if.rdata     = out_if.r_data;
  assign in_if.rresp     = out_if.r_resp;
  assign in_if.rlast    = out_if.r_last;
  assign in_if.rvalid    = out_if.r_valid;
  assign out_if.r_ready  = in_if.rready;

endmodule

module pulp_axi_hc_axi_passthrough (
    AXI_BUS.Slave in_if,
    axi_if.master out_if
);
  // AW channel
  assign out_if.awid    = in_if.aw_id;
  assign out_if.awaddr  = in_if.aw_addr;
  assign out_if.awlen   = in_if.aw_len;
  assign out_if.awsize  = in_if.aw_size;
  assign out_if.awburst = in_if.aw_burst;
  assign out_if.awqos   = in_if.aw_qos;
  assign out_if.awlock  = in_if.aw_lock;
  assign out_if.awvalid = in_if.aw_valid;
  assign in_if.aw_ready = out_if.awready;
  assign out_if.awprot  = '0;

  // W channel
  assign out_if.wdata   = in_if.w_data;
  assign out_if.wstrb   = in_if.w_strb;
  assign out_if.wlast   = in_if.w_last;
  assign out_if.wvalid  = in_if.w_valid;
  assign in_if.wready   = out_if.wready;

  // B channel
  assign in_if.b_id     = out_if.bid;
  assign in_if.bresp    = out_if.bresp;
  assign in_if.bvalid   = out_if.bvalid;
  assign out_if.bready  = in_if.b_ready;

  // AR channel
  assign out_if.arid    = in_if.ar_id;
  assign out_if.araddr  = in_if.ar_addr;
  assign out_if.arlen   = in_if.ar_len;
  assign out_if.arsize  = in_if.ar_size;
  assign out_if.arburst = in_if.ar_burst;
  assign out_if.arqos   = in_if.ar_qos;
  assign out_if.arlock  = in_if.ar_lock;
  assign out_if.arvalid = in_if.ar_valid;
  assign in_if.ar_ready = out_if.arready;
  assign out_if.arprot  = '0;

  // R channel
  assign in_if.r_id     = out_if.rid;
  assign in_if.rdata    = out_if.rdata;
  assign in_if.rresp    = out_if.rresp;
  assign in_if.rlast    = out_if.rlast;
  assign in_if.rvalid   = out_if.rvalid;
  assign out_if.rready  = in_if.r_ready;

endmodule
