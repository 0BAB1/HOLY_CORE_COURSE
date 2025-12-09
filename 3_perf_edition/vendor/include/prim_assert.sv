// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macros and helper code for using assertions.
//  - Provides default clk and rst options to simplify code
//  - Provides boiler plate template for common assertions

/* verilator lint_off UNOPTFLAT */
/* verilator lint_off REDEFMACRO */

`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

///////////////////
// Helper macros //
///////////////////

// Default clk and reset signals used by assertion macros below.
`define ASSERT_DEFAULT_CLK clk_i
`define ASSERT_DEFAULT_RST !rst_ni

// Converts an arbitrary block of code into a Verilog string
`define PRIM_STRINGIFY(__x) `"__x`"

// ASSERT_ERROR logs an error message with either `uvm_error or with $error.
`define ASSERT_ERROR(__name)                                                             \
`ifdef UVM                                                                               \
  uvm_pkg::uvm_report_error("ASSERT FAILED", `PRIM_STRINGIFY(__name), uvm_pkg::UVM_NONE, \
                            `__FILE__, `__LINE__, "", 1);                                \
`else                                                                                    \
  $error("%0t: (%0s:%0d) [%m] [ASSERT FAILED] %0s", $time, `__FILE__, `__LINE__,         \
         `PRIM_STRINGIFY(__name));                                                       \
`endif

// This macro is suitable for conditionally triggering lint errors.
`define ASSERT_STATIC_LINT_ERROR(__name, __prop)     \
  localparam int __name = (__prop) ? 1 : 2;          \
  always_comb begin                                  \
    logic unused_assert_static_lint_error;           \
    unused_assert_static_lint_error = __name'(1'b1); \
  end

// Static assertions for checks inside SV packages.
`define ASSERT_STATIC_IN_PACKAGE(__name, __prop)              \
  function automatic bit assert_static_in_package_``__name(); \
    bit unused_bit [((__prop) ? 1 : -1)];                     \
    unused_bit = '{default: 1'b0};                            \
    return unused_bit[0];                                     \
  endfunction

// Choose implementation headers per tool.
// For SYNTHESIS or VERILATOR we use the dummy macros (no real assertions).
`ifdef VERILATOR
  `include "prim_assert_dummy_macros.svh"
`elsif SYNTHESIS
  `include "prim_assert_dummy_macros.svh"
`elsif YOSYS
  `include "prim_assert_yosys_macros.svh"
  `define INC_ASSERT
`else
  `include "prim_assert_standard_macros.svh"
  `define INC_ASSERT
`endif

//////////////////////////////
// Complex assertion macros //
//////////////////////////////

// ---- ASSERT_PULSE ----
`ifdef SYNTHESIS
  `define ASSERT_PULSE(__name, __sig, __clk, __rst) \
    `ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)
`else
  `define ASSERT_PULSE(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
    `ASSERT(__name, $rose(__sig) |=> !(__sig), __clk, __rst)
`endif

// ---- ASSERT_IF ----
`ifdef SYNTHESIS
  `define ASSERT_IF(__name, __prop, __enable, __clk, __rst) \
    `ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)
`else
  `define ASSERT_IF(__name, __prop, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
    `ASSERT(__name, (__enable) |-> (__prop), __clk, __rst)
`endif

// ---- ASSERT_KNOWN_IF ----
`ifdef SYNTHESIS
  `define ASSERT_KNOWN_IF(__name, __sig, __enable, __clk, __rst) \
  `ifndef FPV_ON                                                  \
    `ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)    \
    `ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)\
  `endif
`else
  `define ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ifndef FPV_ON                                                                                             \
    `ASSERT_KNOWN(__name``KnownEnable, __enable, __clk, __rst)                                               \
    `ASSERT_IF(__name, !$isunknown(__sig), __enable, __clk, __rst)                                           \
  `endif
`endif

//////////////////////////////////
// For formal verification only //
//////////////////////////////////

// ---- ASSUME_FPV ----
`ifdef SYNTHESIS
  `define ASSUME_FPV(__name, __prop, __clk, __rst) \
  `ifdef FPV_ON                                    \
     `ASSUME(__name, __prop, __clk, __rst)         \
  `endif
`else
  `define ASSUME_FPV(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ifdef FPV_ON                                                                               \
     `ASSUME(__name, __prop, __clk, __rst)                                                    \
  `endif
`endif

// ---- ASSUME_I_FPV ---- (no default args anywhere; Vivado-safe as is)
`define ASSUME_I_FPV(__name, __prop) \
`ifdef FPV_ON                        \
   `ASSUME_I(__name, __prop)         \
`endif

// ---- COVER_FPV ----
`ifdef SYNTHESIS
  `define COVER_FPV(__name, __prop, __clk, __rst) \
  `ifdef FPV_ON                                   \
     `COVER(__name, __prop, __clk, __rst)         \
  `endif
`else
  `define COVER_FPV(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
  `ifdef FPV_ON                                                                              \
     `COVER(__name, __prop, __clk, __rst)                                                    \
  `endif
`endif

// ---- ASSERT_FPV_LINEAR_FSM ----
`ifdef SYNTHESIS
  `define ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk, __rst) \
    `ifdef INC_ASSERT                                                   \
      bit __name``_cond;                                                \
      always_ff @(posedge __clk or posedge __rst) begin                 \
        if (__rst) begin                                                \
          __name``_cond <= 0;                                           \
        end else begin                                                  \
          __name``_cond <= 1;                                           \
        end                                                             \
      end                                                               \
      property __name``_p;                                              \
        __type initial_state;                                           \
        (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |-> \
            (__state != initial_state) until !(__name``_cond);          \
      endproperty                                                       \
      `ASSERT(__name, __name``_p, __clk, 0)                             \
    `endif
`else
  `define ASSERT_FPV_LINEAR_FSM(__name, __state, __type, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST) \
    `ifdef INC_ASSERT                                                                                               \
      bit __name``_cond;                                                                                             \
      always_ff @(posedge __clk or posedge __rst) begin                                                              \
        if (__rst) begin                                                                                             \
          __name``_cond <= 0;                                                                                        \
        end else begin                                                                                               \
          __name``_cond <= 1;                                                                                        \
        end                                                                                                          \
      end                                                                                                            \
      property __name``_p;                                                                                           \
        __type initial_state;                                                                                        \
        (!$stable(__state) & __name``_cond, initial_state = $past(__state)) |->                                      \
            (__state != initial_state) until !(__name``_cond);                                                       \
      endproperty                                                                                                    \
      `ASSERT(__name, __name``_p, __clk, 0)                                                                          \
    `endif
`endif

`include "prim_assert_sec_cm.svh"
`include "prim_flop_macros.sv"

`endif // PRIM_ASSERT_SV

/* verilator lint_on UNOPTFLAT */
/* verilator lint_on REDEFMACRO */