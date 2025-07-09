# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs
WAVES = 1

VERILOG_SOURCES += $(PWD)/../holy_clint.sv
EXTRA_ARGS += $(PWD)/../../../packages/holy_core_pkg.sv
EXTRA_ARGS += $(PWD)/../../../packages/axi_lite_if.sv
EXTRA_ARGS += $(PWD)/wrapper.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_clint_wrapper

# MODULE is the basename of the Python test file
MODULE = test_holy_clint

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim