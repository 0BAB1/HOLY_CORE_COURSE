# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
EXTRA_ARGS += --trace --trace-structs

EXTRA_ARGS += --sv -Wno-fatal
WAVES = 1

VERILOG_SOURCES += $(PWD)/../../vendor/axi/src/axi_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/common_cells/src/cf_math_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi/src/axi_intf.sv
VERILOG_SOURCES += $(PWD)/../../vendor/common_verification/src/rand_id_queue.sv
VERILOG_SOURCES += $(PWD)/../../packages/holy_core_pkg.sv
VERILOG_SOURCES += $(PWD)/axi_if_convert.sv
AXI_SRCS := $(wildcard $(PWD)/../../vendor/axi/src/*.sv)
AXI_SRCS := $(filter-out $(PWD)/../../vendor/axi/src/axi_pkg.sv, $(AXI_SRCS))
AXI_SRCS := $(filter-out $(PWD)/../../vendor/axi/src/axi_test.sv, $(AXI_SRCS))
AXI_SRCS := $(filter-out $(PWD)/../../vendor/axi/src/axi_intf.sv, $(AXI_SRCS))
VERILOG_SOURCES += $(AXI_SRCS)
VERILOG_SOURCES += $(PWD)/../../packages/axi_if.sv
VERILOG_SOURCES += $(PWD)/../../packages/axi_lite_if.sv
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_plic/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_clint/*.sv)
VERILOG_SOURCES += $(PWD)/holy_test_harness.sv

# for includes
EXTRA_ARGS += -I$(PWD)/../../vendor/axi/include
EXTRA_ARGS += -I$(PWD)/../../vendor/common_cells/include
EXTRA_ARGS += -I$(PWD)/../../vendor/common_cells/src
EXTRA_ARGS += -I$(PWD)/../../vendor/axi/src

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = holy_test_harness

# MODULE is the basename of the Python test file
MODULE = test_holy_core

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim