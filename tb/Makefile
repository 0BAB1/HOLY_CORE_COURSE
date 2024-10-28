# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../src/cpu.sv

TOPLEVEL = counter

# MODULE is the basename of the Python test file
MODULE = testtb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim