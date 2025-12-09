// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Macro bodies included by prim_assert.sv for tools that don't support assertions. See
// prim_assert.sv for documentation for each of the macros.

/* verilator lint_off UNOPTFLAT */
/* verilator lint_off REDEFMACRO */

`define ASSERT_I(__name, __prop)
`define ASSERT_INIT(__name, __prop)
`define ASSERT_INIT_NET(__name, __prop)
`define ASSERT_FINAL(__name, __prop)
// prim_assert_dummy_macros.svh
// Vivado + Verilator compatible macro definitions

`ifdef SYNTHESIS
  // Vivado (no support for default macro arguments)
  `define ASSERT(__name, __prop, __clk, __rst)
  `define ASSERT_NEVER(__name, __prop, __clk, __rst)
  `define ASSERT_KNOWN(__name, __sig, __clk, __rst)
  `define COVER(__name, __prop, __clk, __rst)
  `define ASSUME(__name, __prop, __clk, __rst)
`else
  // Tools that support default macro arguments (Verilator, VCS, Questa, etc.)
  `define ASSERT(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
  `define ASSERT_NEVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
  `define ASSERT_KNOWN(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
  `define COVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
  `define ASSUME(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`endif
`define ASSUME_I(__name, __prop)

/* verilator lint_on UNOPTFLAT */
/* verilator lint_on REDEFMACRO */