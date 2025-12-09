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
EXTRA_ARGS += --trace --trace-structs --sv
WAVES ?= 1

TOPLEVEL = holy_test_harness

MODULE = test_holy_core

# Verilog sources (packages)
VERILOG_SOURCES += $(PWD)/../../vendor/axi_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/cf_math_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_intf.sv
VERILOG_SOURCES += $(PWD)/../../vendor/rand_id_queue.sv
VERILOG_SOURCES += $(PWD)/../../packages/holy_core_pkg.sv
VERILOG_SOURCES += $(PWD)/axi_if_convert.sv

# external sources (mainly customized pulp platform files)
VERILOG_SOURCES += $(PWD)/../../vendor/delta_counter.sv
VERILOG_SOURCES += $(PWD)/../../vendor/counter.sv
VERILOG_SOURCES += $(PWD)/../../vendor/fifo_v3.sv
VERILOG_SOURCES += $(PWD)/../../vendor/spill_register_flushable.sv
VERILOG_SOURCES += $(PWD)/../../vendor/spill_register.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_lite_xbar.sv
VERILOG_SOURCES += $(PWD)/../../vendor/addr_decode_dync.sv
VERILOG_SOURCES += $(PWD)/../../vendor/addr_decode.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_lite_demux.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_lite_mux.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_lite_to_axi.sv
VERILOG_SOURCES += $(PWD)/../../vendor/axi_err_slv.sv

# pulp riscv dbg related
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/debug_rom/debug_rom.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_util_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_fifo_sync_cnt.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_fifo_sync.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_flop_2sync.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_clock_inv.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_generic_clock_mux2.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_generic_flop.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_sync_reqack.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_flop.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_clock_mux2.sv
VERILOG_SOURCES += $(PWD)/../../vendor/prim_fifo_async_simple.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dm_pkg.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dmi_cdc.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dmi_jtag_tap.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dmi_jtag.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dm_csrs.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dm_sba.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dm_mem.sv
VERILOG_SOURCES += $(PWD)/../../vendor/pulp-riscv-dbg/src/dm_top.sv


# holy core sources
VERILOG_SOURCES += $(PWD)/../../packages/axi_if.sv
VERILOG_SOURCES += $(PWD)/../../packages/axi_lite_if.sv
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_plic/*.sv)
VERILOG_SOURCES += $(wildcard $(PWD)/../../src/holy_clint/*.sv)
VERILOG_SOURCES += $(PWD)/holy_test_harness.sv

EXTRA_ARGS += -I$(PWD)/../../vendor/include
EXTRA_ARGS += -I$(PWD)/../../vendor/include/axi
EXTRA_ARGS += -I$(PWD)/../../vendor/include/common_cells

##################################
# COMPILE TEST ASSEMBLY
##################################

ARCH        := rv32i_zicsr
ABI         := ilp32
CC          := riscv64-unknown-elf-gcc
OBJCOPY     := riscv64-unknown-elf-objcopy
OBJDUMP     := riscv64-unknown-elf-objdump
HEXTOOL     := hexdump

SRC         := test.s
OUT_ELF     := test.elf
OUT_BIN     := test.bin
OUT_HEX     := test.hex
OUT_DIS     := test.D

CFLAGS  := -march=$(ARCH) -mabi=$(ABI) -static -mcmodel=medany \
           -fvisibility=hidden -nostdlib -nostartfiles -g -Wl,-Ttext=0x0

# === HEX generation ===
$(OUT_ELF): $(SRC)
	$(CC) $(CFLAGS) $< -o $@

$(OUT_BIN): $(OUT_ELF)
	$(OBJCOPY) -O binary --gap-fill=0x00 $< $@

$(OUT_HEX): $(OUT_BIN)
	$(HEXTOOL) -v -e '1/4 "%08x\n"' $< > $@

# === Generate Disassembly ===
$(OUT_DIS): $(OUT_ELF)
	$(OBJDUMP) -d $< > $@

# === Default target ===
all: $(OUT_ELF) $(OUT_BIN) $(OUT_HEX) $(OUT_DIS) dump

##################################
# MAIN TARGET: build HEX + run sim
##################################

sim: $(OUT_HEX) $(OUT_DIS)
	$(MAKE) SIM=$(SIM) TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) VERILOG_SOURCES="$(VERILOG_SOURCES)" EXTRA_ARGS="$(EXTRA_ARGS)" WAVES=$(WAVES) -f $(shell cocotb-config --makefiles)/Makefile.sim

dump: $(OUT_ELF)
	riscv32-unknown-elf-objdump -d $(OUT_ELF) > $(OUT_DIS)
	@echo "Disassembly written to $(OUT_DIS)"

##################################
# CLEAN
##################################

clean:
	rm -f $(OUT_ELF) $(OUT_BIN) $(OUT_HEX) $(OUT_DIS)
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim clean

.PHONY: sim clean
