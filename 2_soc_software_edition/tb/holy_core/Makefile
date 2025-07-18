# Holy core tb Makefile
#
# BRH 07/25
#
# Uses cocotb + verilator + RISCV toolchain

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

EXTRA_ARGS += -I$(PWD)/../../vendor/axi/include
EXTRA_ARGS += -I$(PWD)/../../vendor/common_cells/include
EXTRA_ARGS += -I$(PWD)/../../vendor/common_cells/src
EXTRA_ARGS += -I$(PWD)/../../vendor/axi/src

##################################
# COMPILE TEST ASSEMBLY
##################################

ARCH        := rv32i_zicsr
ABI         := ilp32
CC          := riscv64-unknown-elf-gcc
OBJCOPY     := riscv64-unknown-elf-objcopy
HEXTOOL     := hexdump

SRC         := test.S
OUT_ELF     := test.elf
OUT_BIN     := test.bin
OUT_HEX     := test.hex

LINKER_SCRIPT := ./test_link.ld

CFLAGS  := -march=$(ARCH) -mabi=$(ABI) -static -mcmodel=medany \
           -fvisibility=hidden -nostdlib -nostartfiles -g \
           -T $(LINKER_SCRIPT)

# === HEX generation ===
$(OUT_ELF): $(SRC)
	$(CC) $(CFLAGS) $< -o $@

$(OUT_BIN): $(OUT_ELF)
	$(OBJCOPY) -O binary --gap-fill=0x00 $< $@

$(OUT_HEX): $(OUT_BIN)
	$(HEXTOOL) -v -e '1/4 "%08x\n"' $< > $@

##################################
# MAIN TARGET: build HEX + run sim
##################################

sim: $(OUT_HEX)
	$(MAKE) SIM=$(SIM) TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) VERILOG_SOURCES="$(VERILOG_SOURCES)" EXTRA_ARGS="$(EXTRA_ARGS)" WAVES=$(WAVES) -f $(shell cocotb-config --makefiles)/Makefile.sim

##################################
# CLEAN
##################################

clean:
	rm -f $(OUT_ELF) $(OUT_BIN) $(OUT_HEX)
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim clean

.PHONY: sim clean
