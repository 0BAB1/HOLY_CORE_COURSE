// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef PRIM_FLOP_MACROS_SV
`define PRIM_FLOP_MACROS_SV

/////////////////////////////////////
// Default Values for Macros below //
/////////////////////////////////////

`define PRIM_FLOP_CLK clk_i
`define PRIM_FLOP_RST rst_ni
`define PRIM_FLOP_RESVAL '0

/////////////////////
// Register Macros //
/////////////////////

// Register with asynchronous reset.
// Vivado (SYNTHESIS) doesn't allow default args in macros.
`ifdef SYNTHESIS
  `define PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n) \
    always_ff @(posedge __clk or negedge __rst_n) begin   \
      if (!__rst_n) begin                                 \
        __q <= __resval;                                  \
      end else begin                                      \
        __q <= __d;                                       \
      end                                                 \
    end
`else
  `define PRIM_FLOP_A(__d, __q, __resval = `PRIM_FLOP_RESVAL, __clk = `PRIM_FLOP_CLK, __rst_n = `PRIM_FLOP_RST) \
    always_ff @(posedge __clk or negedge __rst_n) begin                                                          \
      if (!__rst_n) begin                                                                                        \
        __q <= __resval;                                                                                         \
      end else begin                                                                                             \
        __q <= __d;                                                                                              \
      end                                                                                                        \
    end
`endif

///////////////////////////
// Macro for Sparse FSMs //
///////////////////////////

// FSM flop wrapper. Same trick for synthesis vs. simulation.
`ifdef SYNTHESIS
  `define PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval, __clk, __rst_n, __alert_trigger_sva_en) \
    prim_sparse_fsm_flop #(                                                                                 \
      .StateEnumT(__type),                                                                                  \
      .Width($bits(__type)),                                                                                \
      .ResetValue($bits(__type)'(__resval)),                                                                \
      .EnableAlertTriggerSVA(__alert_trigger_sva_en)                                                        \
    ) __name (                                                                                              \
      .clk_i   ( __clk   ),                                                                                 \
      .rst_ni  ( __rst_n ),                                                                                 \
      .state_i ( __d     ),                                                                                 \
      .state_o ( __q     )                                                                                  \
    );
`else
  `define PRIM_FLOP_SPARSE_FSM(__name, __d, __q, __type, __resval = `PRIM_FLOP_RESVAL, __clk = `PRIM_FLOP_CLK, __rst_n = `PRIM_FLOP_RST, __alert_trigger_sva_en = 1) \
    `ifdef SIMULATION                                                                                                          \
      prim_sparse_fsm_flop #(                                                                                                  \
        .StateEnumT(__type),                                                                                                   \
        .Width($bits(__type)),                                                                                                 \
        .ResetValue($bits(__type)'(__resval)),                                                                                 \
        .EnableAlertTriggerSVA(__alert_trigger_sva_en),                                                                        \
        .CustomForceName(`PRIM_STRINGIFY(__q))                                                                                 \
      ) __name (                                                                                                               \
        .clk_i   ( __clk   ),                                                                                                  \
        .rst_ni  ( __rst_n ),                                                                                                  \
        .state_i ( __d     ),                                                                                                  \
        .state_o (         )                                                                                                   \
      );                                                                                                                       \
      `PRIM_FLOP_A(__d, __q, __resval, __clk, __rst_n)                                                                         \
      `ASSERT(``__name``_A, __q === ``__name``.state_o)                                                                        \
    `else                                                                                                                      \
      prim_sparse_fsm_flop #(                                                                                                  \
        .StateEnumT(__type),                                                                                                   \
        .Width($bits(__type)),                                                                                                 \
        .ResetValue($bits(__type)'(__resval)),                                                                                 \
        .EnableAlertTriggerSVA(__alert_trigger_sva_en)                                                                         \
      ) __name (                                                                                                               \
        .clk_i   ( __clk   ),                                                                                                  \
        .rst_ni  ( __rst_n ),                                                                                                  \
        .state_i ( __d     ),                                                                                                  \
        .state_o ( __q     )                                                                                                   \
      );                                                                                                                       \
    `endif
`endif

`endif // PRIM_FLOP_MACROS_SV
