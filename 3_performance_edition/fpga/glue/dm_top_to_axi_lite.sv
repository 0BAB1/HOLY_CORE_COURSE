/** Glue logic for debug module
*
*   Author : BRH
*/

`include "typedef.svh"
`include "assign.svh"

import holy_core_pkg::*;
import axi_pkg::*;

module dm_top_to_axi_lite (
    // CPU LOGIC CLOCK & RESET
    input logic clk,
    input logic rst_n,

    // dm_top Interface
    input logic         req_i,
    input logic [31:0]  add_i,
    input logic         we_i,
    input logic [31:0]  wdata_i,
    input logic [3:0]   be_i,
    output logic         gnt_o,
    output logic         r_valid_o,
    output logic [31:0]  r_rdata_o,

    // AXI LITE Interface for external requests
    axi_lite_if.master out_if_axil_m
);

    // BASED ON PULP'S CONVERTER
    AXI_LITE #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32)
    ) mst_pulp_axi();

    // Fucking macros are broken, so type definitions here
    typedef logic [31:0]   addr_t;
    typedef logic [31:0]   data_t;
    typedef logic [3:0] strb_t;

    typedef struct packed {                                   
        addr_t          addr;
        axi_pkg::prot_t prot;
    } aw_chan_lite_t;

    typedef struct packed {
        data_t   data;
        strb_t   strb;
    } w_chan_lite_t;

    typedef struct packed {
        axi_pkg::resp_t resp;
    } b_chan_lite_t;

    typedef struct packed {
        addr_t          addr;
        axi_pkg::prot_t prot;
    } ar_chan_lite_t;

    typedef struct packed {
        data_t          data;
        axi_pkg::resp_t resp;
    } r_chan_lite_t;

    typedef struct packed {
        aw_chan_lite_t aw;   
        logic          aw_valid; 
        w_chan_lite_t  w; 
        logic          w_valid;    
        logic          b_ready;
        ar_chan_lite_t ar;
        logic          ar_valid;
        logic          r_ready;
    } req_lite_t;
   
   typedef struct packed {   
        logic          aw_ready;
        logic          w_ready; 
        b_chan_lite_t  b;
        logic          b_valid; 
        logic          ar_ready;
        r_chan_lite_t  r;
        logic          r_valid; 
    } resp_lite_t;

    req_lite_t                   axi_lite_req;
    resp_lite_t                  axi_lite_resp;

    // assign req and rest to actual interface
    // have to do it ourselve because the fucking macro don't work,
    // which is what happens when you do nerdy shit like
    // Oh MaCrOs ArE sO hAnDy DanDy
    // like no omfg it is not intuitive and does not fucking work.
    // anyways, here is to a other hours, lost, to trying to glue brick
    // toghether instead of solving real problems. Great. I lose SO MUCH time
    // like this, that I wonder if starting to pull open source code
    // really was a gain of time. I should've made EVERYTHING my self ffs.
    
    // AW Channel
    assign mst_pulp_axi.aw_valid = axi_lite_req.aw_valid;
    assign mst_pulp_axi.aw_addr = axi_lite_req.aw.addr;
    assign mst_pulp_axi.aw_prot = 3'b000;
    assign axi_lite_resp.aw_ready = mst_pulp_axi.aw_ready;

    // W Channel
    assign mst_pulp_axi.w_valid = axi_lite_req.w_valid;
    assign mst_pulp_axi.w_data = axi_lite_req.w.data;
    assign mst_pulp_axi.w_strb = axi_lite_req.w.strb;
    assign axi_lite_resp.w_ready = mst_pulp_axi.w_ready;

    // B Channel
    assign mst_pulp_axi.b_ready = axi_lite_req.b_ready;
    assign axi_lite_resp.b.resp = mst_pulp_axi.b_resp;
    assign axi_lite_resp.b_valid = mst_pulp_axi.b_valid;

    // AR Channel
    assign mst_pulp_axi.ar_valid = axi_lite_req.ar_valid;
    assign mst_pulp_axi.ar_addr = axi_lite_req.ar.addr;
    assign mst_pulp_axi.ar_prot = 3'b000;
    assign axi_lite_resp.ar_ready = mst_pulp_axi.ar_ready;

    // R Channel
    assign mst_pulp_axi.r_ready = axi_lite_req.r_ready;
    assign axi_lite_resp.r.data = mst_pulp_axi.r_data;
    assign axi_lite_resp.r.resp = mst_pulp_axi.r_resp;
    assign axi_lite_resp.r_valid = mst_pulp_axi.r_valid;

    // wow, i had so musch fun making these assigns by fucking hand
    // like each and every fucking time men. fuck.

    axi_lite_from_mem #(
        .MemAddrWidth(32'd32),
        .AxiAddrWidth(32'd32),
        .DataWidth(32'd32),
        .MaxRequests(32'd1), // (Depth of the response mux FIFO).
        .AxiProt(3'b000),
        .axi_req_t(req_lite_t),
        .axi_rsp_t(resp_lite_t)
    ) pulp_conv (
        .clk_i(clk),
        .rst_ni(rst_n),
        .mem_req_i(req_i),
        .mem_addr_i(add_i),
        .mem_we_i(we_i),
        .mem_wdata_i(wdata_i),
        .mem_be_i(be_i),
        .mem_gnt_o(gnt_o),
        .mem_rsp_valid_o(r_valid_o),
        .mem_rsp_rdata_o(r_rdata_o),
        .mem_rsp_error_o(), // not used
        .axi_req_o(axi_lite_req),
        .axi_rsp_i(axi_lite_resp)
    );

    // Convert master to holy_core's interface definition
    pulp_axil_hc_axil_passthrough conv_pulp_hc(
        .in_if(mst_pulp_axi),
        .out_if(out_if_axil_m)
    );

endmodule
