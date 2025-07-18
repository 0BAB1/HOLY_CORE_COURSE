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