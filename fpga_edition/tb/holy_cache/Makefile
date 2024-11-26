# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs
WAVES = 1

VERILOG_SOURCES += $(PWD)/../../src/holy_cache.sv
EXTRA_ARGS += $(PWD)/../../packages/holy_core_pkg.sv
EXTRA_ARGS += $(PWD)/../../packages/axi_if.sv
EXTRA_ARGS += $(PWD)/axi_translator.sv
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = axi_translator

# MODULE is the basename of the Python test file
MODULE = test_holy_cache

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim