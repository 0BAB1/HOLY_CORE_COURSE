# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs
WAVES = 1

VERILOG_SOURCES += $(wildcard $(PWD)/../../src/*.sv)
EXTRA_ARGS += $(PWD)/../../packages/holy_core_pkg.sv
EXTRA_ARGS += $(PWD)/../../packages/axi_if.sv
EXTRA_ARGS += $(PWD)/../../packages/axi_lite_if.sv
EXTRA_ARGS += $(PWD)/holy_test_harness.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_test_harness

# MODULE is the basename of the Python test file
MODULE = test_holy_core

# HEX FILE ABSOLUTE PATH TO PROGRAM
IHEX_PATH ?= $(PWD)/test_imemory.hex
export IHEX_PATH
begin_signature ?= fool
export begin_signature
end_signature ?= fool
export end_signature
write_tohost ?= fool
export write_tohost

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
