// Copyright (c) 2014-2018 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>

/// An AXI4-Lite to AXI4 adapter.
module axi_lite_to_axi #(
  parameter int unsigned AxiDataWidth = 32'd0,
  // LITE AXI structs
  parameter type  req_lite_t = logic,
  parameter type resp_lite_t = logic,
  // FULL AXI structs
  parameter type   axi_req_t = logic,
  parameter type  axi_resp_t = logic
) (
  // Slave AXI LITE port
  input  req_lite_t       slv_req_lite_i,
  output resp_lite_t      slv_resp_lite_o,
  input  axi_pkg::cache_t slv_aw_cache_i,
  input  axi_pkg::cache_t slv_ar_cache_i,
  // Master AXI port
  output axi_req_t        mst_req_o,
  input  axi_resp_t       mst_resp_i
);
  /* verilator lint_off WIDTHEXPAND */
  /* verilator lint_off WIDTHTRUNC */
  localparam int unsigned AxiSize = axi_pkg::size_t'($unsigned($clog2(AxiDataWidth/8)));

  // request assign
  assign mst_req_o = '{
    aw: '{
      addr:  slv_req_lite_i.aw.addr,
      prot:  slv_req_lite_i.aw.prot,
      size:  AxiSize,
      burst: axi_pkg::BURST_FIXED,
      cache: slv_aw_cache_i,
      default: '0
    },
    aw_valid: slv_req_lite_i.aw_valid,
    w: '{
      data: slv_req_lite_i.w.data,
      strb: slv_req_lite_i.w.strb,
      last: 1'b1,
      default: '0
    },
    w_valid: slv_req_lite_i.w_valid,
    b_ready: slv_req_lite_i.b_ready,
    ar: '{
      addr:  slv_req_lite_i.ar.addr,
      prot:  slv_req_lite_i.ar.prot,
      size:  AxiSize,
      burst: axi_pkg::BURST_FIXED,
      cache: slv_ar_cache_i,
      default: '0
    },
    ar_valid: slv_req_lite_i.ar_valid,
    r_ready:  slv_req_lite_i.r_ready,
    default:   '0
  };
  // response assign
  assign slv_resp_lite_o = '{
    aw_ready: mst_resp_i.aw_ready,
    w_ready:  mst_resp_i.w_ready,
    b: '{
      resp: mst_resp_i.b.resp,
      default: '0
    },
    b_valid:  mst_resp_i.b_valid,
    ar_ready: mst_resp_i.ar_ready,
    r: '{
      data: mst_resp_i.r.data,
      resp: mst_resp_i.r.resp,
      default: '0
    },
    r_valid: mst_resp_i.r_valid,
    default: '0
  };

  // pragma translate_off
  `ifndef VERILATOR
  initial begin
    assert (AxiDataWidth > 0) else $fatal(1, "Data width must be non-zero!");
  end
  `endif
  // pragma translate_on
endmodule

module axi_lite_to_axi_intf #(
  parameter int unsigned AXI_DATA_WIDTH = 32'd0
) (
  AXI_LITE.Slave  in_if,
  input axi_pkg::cache_t slv_aw_cache_i,
  input axi_pkg::cache_t slv_ar_cache_i,
  AXI_BUS.Master  out_if
);
  localparam int unsigned AxiSize = axi_pkg::size_t'($unsigned($clog2(AXI_DATA_WIDTH/8)));

// pragma translate_off
  initial begin
    assert(in_if.AXI_ADDR_WIDTH == out_if.AXI_ADDR_WIDTH);
    assert(in_if.AXI_DATA_WIDTH == out_if.AXI_DATA_WIDTH);
    assert(AXI_DATA_WIDTH    == out_if.AXI_DATA_WIDTH);
  end
// pragma translate_on

  assign out_if.aw_id     = '0;
  assign out_if.aw_addr   = in_if.aw_addr;
  assign out_if.aw_len    = '0;
  assign out_if.aw_size   = axi_pkg::size_t'(AxiSize);
  assign out_if.aw_burst  = axi_pkg::BURST_FIXED;
  assign out_if.aw_lock   = '0;
  assign out_if.aw_cache  = slv_aw_cache_i;
  assign out_if.aw_prot   = '0;
  assign out_if.aw_qos    = '0;
  assign out_if.aw_region = '0;
  assign out_if.aw_atop   = '0;
  assign out_if.aw_user   = '0;
  assign out_if.aw_valid  = in_if.aw_valid;
  assign in_if.aw_ready   = out_if.aw_ready;

  assign out_if.w_data    = in_if.w_data;
  assign out_if.w_strb    = in_if.w_strb;
  assign out_if.w_last    = '1;
  assign out_if.w_user    = '0;
  assign out_if.w_valid   = in_if.w_valid;
  assign in_if.w_ready    = out_if.w_ready;

  assign in_if.b_resp     = out_if.b_resp;
  assign in_if.b_valid    = out_if.b_valid;
  assign out_if.b_ready   = in_if.b_ready;

  assign out_if.ar_id     = '0;
  assign out_if.ar_addr   = in_if.ar_addr;
  assign out_if.ar_len    = '0;
  assign out_if.ar_size   = axi_pkg::size_t'(AxiSize);
  assign out_if.ar_burst  = axi_pkg::BURST_FIXED;
  assign out_if.ar_lock   = '0;
  assign out_if.ar_cache  = slv_ar_cache_i;
  assign out_if.ar_prot   = '0;
  assign out_if.ar_qos    = '0;
  assign out_if.ar_region = '0;
  assign out_if.ar_user   = '0;
  assign out_if.ar_valid  = in_if.ar_valid;
  assign in_if.ar_ready   = out_if.ar_ready;

  assign in_if.r_data     = out_if.r_data;
  assign in_if.r_resp     = out_if.r_resp;
  assign in_if.r_valid    = out_if.r_valid;
  assign out_if.r_ready   = in_if.r_ready;

  /* verilator lint_on WIDTHEXPAND */
  /* verilator lint_on WIDTHTRUNC */
endmodule
