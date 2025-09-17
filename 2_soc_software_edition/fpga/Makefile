# Holy core tb Makefile
#
# BRH 07/25
#
# Uses cocotb + verilator
# this one is simply to lint the sv top files we'll feed to vivado

##################################
# SIMULATION CONFIG (cocotb)
##################################

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs --sv -Wno-fatal
WAVES ?= 1

TOPLEVEL = holy_test_harness
MODULE   = test_holy_core

# Verilog sources
VERILOG_SOURCES += $(PWD)/../vendor/axi_pkg.sv
VERILOG_SOURCES += $(PWD)/../vendor/cf_math_pkg.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_intf.sv
VERILOG_SOURCES += $(PWD)/../vendor/rand_id_queue.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_assert.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_util_pkg.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dm_pkg.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/debug_rom/debug_rom.sv
VERILOG_SOURCES += $(PWD)/../vendor/addr_decode_dync.sv
VERILOG_SOURCES += $(PWD)/../vendor/addr_decode.sv

VERILOG_SOURCES += $(PWD)/../vendor/prim_fifo_sync_cnt.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_generic_clock_mux2.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_clock_inv.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_clock_mux2.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_generic_flop.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_flop.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_flop_2sync.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_sync_reqack.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_fifo_async_simple.sv
VERILOG_SOURCES += $(PWD)/../vendor/prim_fifo_sync.sv
VERILOG_SOURCES += $(PWD)/../vendor/fifo_v3.sv
VERILOG_SOURCES += $(PWD)/../vendor/delta_counter.sv
VERILOG_SOURCES += $(PWD)/../vendor/counter.sv
VERILOG_SOURCES += $(PWD)/../vendor/spill_register.sv
VERILOG_SOURCES += $(PWD)/../vendor/spill_register_flushable.sv

VERILOG_SOURCES += $(PWD)/../packages/holy_core_pkg.sv
VERILOG_SOURCES += $(PWD)/../tb/holy_core/axi_if_convert.sv

VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dm_csrs.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dmi_jtag_tap.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dmi_cdc.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dm_sba.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dm_mem.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dmi_jtag.sv
VERILOG_SOURCES += $(PWD)/../vendor/pulp-riscv-dbg/src/dm_top.sv

VERILOG_SOURCES += $(PWD)/../vendor/stream_join_dynamic.sv
VERILOG_SOURCES += $(PWD)/../vendor/stream_join.sv
VERILOG_SOURCES += $(PWD)/../vendor/stream_fifo.sv
VERILOG_SOURCES += $(PWD)/../vendor/stream_fork_dynamic.sv
VERILOG_SOURCES += $(PWD)/../vendor/stream_fork.sv
VERILOG_SOURCES += $(PWD)/../vendor/stream_mux.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_to_detailed_mem.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_to_mem.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_lite_to_axi.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_lite_mux.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_err_slv.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_lite_demux.sv
VERILOG_SOURCES += $(PWD)/../vendor/axi_lite_xbar.sv

# go on
VERILOG_SOURCES += $(PWD)/../packages/axi_if.sv
VERILOG_SOURCES += $(PWD)/../packages/axi_lite_if.sv
VERILOG_SOURCES += $(PWD)/glue/axi_lite_to_dm_top.sv
VERILOG_SOURCES += $(wildcard $(PWD)/../src/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../src/holy_plic/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../src/holy_clint/*.sv)

# top module
VERILOG_SOURCES += $(PWD)/holy_top.sv

# includes
EXTRA_ARGS += -I$(PWD)/../vendor/include
EXTRA_ARGS += -I$(PWD)/../vendor/include/common_cells
EXTRA_ARGS += -I$(PWD)/../vendor/include/axi

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_top

# MODULE is the basename of the Python test file
MODULE = test_run_lint

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim