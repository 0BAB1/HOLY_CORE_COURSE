# riscof tb's Makefile
#
# This Makefile is here to run the test, but this is not possible manually and happens
# automatically when running the runcof tests procedure.
#
# If you are looking to modify the test startup code, look into start.Makefile
# (make -f start.Makefile)
#
# BRH 11/25


##################################
# SIMULATION CONFIG (cocotb x riscof)
##################################

SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs --sv -Wno-fatal
WAVES ?= 1

TOPLEVEL = holy_test_harness
MODULE   = test_holy_core

# Verilog sources
VERILOG_SOURCES += $(PWD)/../../vendor/axi_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/cf_math_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_intf.sv
VERILOG_SOURCES += $(PWD)/../../vendor/rand_id_queue.sv
VERILOG_SOURCES += $(PWD)/../../packages/holy_core_pkg.sv
VERILOG_SOURCES += $(PWD)/../../tb/holy_core/axi_if_convert.sv

VERILOG_SOURCES += $(PWD)/../../vendor/axi_lite_xbar.sv

VERILOG_SOURCES += $(PWD)/../../packages/axi_if.sv
VERILOG_SOURCES += $(PWD)/../../packages/axi_lite_if.sv
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_plic/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_clint/*.sv)
VERILOG_SOURCES += $(PWD)/holy_test_harness.sv

EXTRA_ARGS += -I$(PWD)/../../vendor/include/axi
EXTRA_ARGS += -I$(PWD)/../../vendor/include/common_cells
EXTRA_ARGS += -I$(PWD)/../../vendor/include
EXTRA_ARGS += -I$(PWD)/../../vendor

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_test_harness

# MODULE is the basename of the Python test file
MODULE = test_holy_core

# HEX FILE ABSOLUTE PATH TO PROGRAM AND LABELS
# set to fool if not set before as this makefile is supposed
# to be called during the ricof test procdure !
IHEX_PATH ?= fool
export IHEX_PATH
begin_signature ?= fool
export begin_signature
end_signature ?= fool
export end_signature
write_tohost ?= fool
export write_tohost

# Include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
