# VIVADO SETUP
#
# TARGET BOARD : KC705
#
# This scripts automates the integration of core in a basic SoC
# (run at root of this codebase)
#
# BRH 08/25

# Create a new project
create_project holy_soc_project /tmp/HC_ETHERNET -part xc7k325tffg900-2 -force
set_property board_part xilinx.com:kc705:part0:1.7 [current_project]

################################################
# SOURCE FILES
################################################

# Add constraint file
add_files -fileset constrs_1 -norecurse ./constraints/kc705.xdc

add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/include/*.sv]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/include/*.svh]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/include/common_cells/*.svh]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/include/axi/*.svh]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/fpga/glue/*.sv]

set script_dir [file dirname [file normalize [info script]]]
set_property include_dirs [list \
    "$script_dir/HOLY_CORE_COURSE/3_perf_edition/vendor/include" \
    "$script_dir/HOLY_CORE_COURSE/3_perf_edition/vendor/include/common_cells" \
    "$script_dir/HOLY_CORE_COURSE/3_perf_edition/vendor/include/axi" \
] [current_fileset]

# Add source files
add_files -norecurse {
    ./HOLY_CORE_COURSE/3_perf_edition/fpga/holy_top.v
    ./HOLY_CORE_COURSE/3_perf_edition/src/holy_data_cache.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/holy_no_cache.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/holy_instr_cache.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/control.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/reader.sv
    ./HOLY_CORE_COURSE/3_perf_edition/packages/axi_if.sv
    ./HOLY_CORE_COURSE/3_perf_edition/packages/axi_lite_if.sv
    ./HOLY_CORE_COURSE/3_perf_edition/packages/holy_core_pkg.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/regfile.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/external_req_arbitrer.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/alu.sv
    ./HOLY_CORE_COURSE/3_perf_edition/fpga/holy_top.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/holy_core.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/signext.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/load_store_decoder.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/csr_file.sv
    ./HOLY_CORE_COURSE/3_perf_edition/src/mul_div_unit.sv
    ./HOLY_CORE_COURSE/3_perf_edition/tb/holy_core/axi_if_convert.sv
    ./HOLY_CORE_COURSE/3_perf_edition/fpga/boot_rom.sv
    ./HOLY_CORE_COURSE/3_perf_edition/fpga/ROM/boot_rom.v
}

add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/*.sv]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/*.svh]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/pulp-riscv-dbg/debug_rom/*.sv]
add_files [glob ./HOLY_CORE_COURSE/3_perf_edition/vendor/pulp-riscv-dbg/src/*.sv]

add_files -norecurse {
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_clint/holy_clint.sv
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_clint/holy_clint_wrapper.sv
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_clint/holy_clint_top.v
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_plic/holy_plic.sv
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_plic/holy_plic_wrapper.sv
  ./HOLY_CORE_COURSE/3_perf_edition/src/holy_plic/holy_plic_top.v
}

# use bscane tap, so we ditch the original
remove_files  /home/deos/hu.babin-riby/Documents/Code/simple-ethernet/HOLY_CORE_COURSE/3_perf_edition/vendor/pulp-riscv-dbg/src/dmi_jtag_tap.sv

# Update compile order
update_compile_order -fileset sources_1

################################################
# ADD HOLY CORE
################################################

# Create and configure the block design
create_bd_design "design_1"
create_bd_cell -type module -reference top top_0

# ---------
# Add 25MHz clock
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 holy_core_only_clk_gen
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {181.828} \
  CONFIG.CLKOUT1_PHASE_ERROR {104.359} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25} \
  CONFIG.CLK_OUT1_PORT {clk_25} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {9.125} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {36.500} \
] [get_bd_cells holy_core_only_clk_gen]
connect_bd_net [get_bd_pins holy_core_only_clk_gen/clk_25] [get_bd_pins top_0/clk]
# input clock for KC705
set_property -dict [list CONFIG.PRIM_IN_FREQ.VALUE_SRC USER] [get_bd_cells holy_core_only_clk_gen]
set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {50.0} \
  CONFIG.CLKOUT1_JITTER {178.502} \
  CONFIG.MMCM_CLKIN1_PERIOD {5.000} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_DIVCLK_DIVIDE {2} \
  CONFIG.PRIM_IN_FREQ {200} \
  CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
] [get_bd_cells holy_core_only_clk_gen]
make_bd_intf_pins_external  [get_bd_intf_pins holy_core_only_clk_gen/CLK_IN1_D]
set_property name sys_diff_clock [get_bd_intf_ports CLK_IN1_D_0]
# ---------

# ---------
# Add resets
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( FPGA Reset ) } Manual_Source {Auto}}  [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins holy_core_only_clk_gen/clk_25]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins proc_sys_reset_0/aux_reset_in]
connect_bd_net [get_bd_pins holy_core_only_clk_gen/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] [get_bd_cells util_vector_logic_0]
connect_bd_net [get_bd_pins proc_sys_reset_0/mb_reset] [get_bd_pins util_vector_logic_0/Op1]
connect_bd_net [get_bd_pins util_vector_logic_0/Res] [get_bd_pins top_0/rst_n]
connect_bd_net [get_bd_pins top_0/periph_rst_n] [get_bd_pins util_vector_logic_0/Res]
# ---------

# JTAG external for debug
# NOTE : Unused, we use pulp bscane dmi tap as drop, in replacement
# so these ports can be left unconnected as JTAG debug is handled by BSCANE primitive
# make_bd_pins_external  [get_bd_pins top_0/trst_ni] [get_bd_pins top_0/tms_i] [get_bd_pins top_0/tck_i] [get_bd_pins top_0/td_i]
# set_property name tck_i [get_bd_ports tck_i_0]
# set_property name tms_i [get_bd_ports tms_i_0]
# set_property name trst_ni [get_bd_ports trst_ni_0]
# set_property name td_i [get_bd_ports td_i_0]
# make_bd_pins_external  [get_bd_pins top_0/td_o]
# set_property name td_o [get_bd_ports td_o_0]

################################################
# BASIC PERIPHERALS
################################################

# we add basic peripherals so we know CPU is alive and help basic debugging via UART

# ---------
# Add GPIO +  AXI SMC
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0
connect_bd_intf_net [get_bd_intf_pins top_0/m_axi_lite] [get_bd_intf_pins smartconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_net [get_bd_pins axi_gpio_0/s_axi_aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
connect_bd_net [get_bd_pins smartconnect_0/aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
set_property CONFIG.GPIO_BOARD_INTERFACE {led_8bits} [get_bd_cells axi_gpio_0]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {led_8bits ( LED ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_gpio_0/GPIO]
# ---------

# ---------
# Add UART
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
set_property CONFIG.NUM_MI {2} [get_bd_cells smartconnect_0]
connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins smartconnect_0/M01_AXI]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
set_property CONFIG.UARTLITE_BOARD_INTERFACE {rs232_uart} [get_bd_cells axi_uartlite_0]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {rs232_uart ( UART ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_uartlite_0/UART]
# ---------

# ---------
# Add basic core ILA
connect_bd_net -net instruction [get_bd_pins top_0/instruction]
connect_bd_net -net pc_next [get_bd_pins top_0/pc_next]
connect_bd_net -net i_cache_stall [get_bd_pins top_0/i_cache_stall]
connect_bd_net -net pc [get_bd_pins top_0/pc]
connect_bd_net -net d_cache_stall [get_bd_pins top_0/d_cache_stall]
set_property HDL_ATTRIBUTE.DEBUG true [get_bd_nets {instruction pc_next i_cache_stall pc d_cache_stall }]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
  [get_bd_nets d_cache_stall] {PROBE_TYPE "Data and Trigger" CLK_SRC "/holy_core_only_clk_gen/clk_25" SYSTEM_ILA "Auto" } \
  [get_bd_nets i_cache_stall] {PROBE_TYPE "Data and Trigger" CLK_SRC "/holy_core_only_clk_gen/clk_25" SYSTEM_ILA "Auto" } \
  [get_bd_nets instruction] {PROBE_TYPE "Data and Trigger" CLK_SRC "/holy_core_only_clk_gen/clk_25" SYSTEM_ILA "Auto" } \
  [get_bd_nets pc] {PROBE_TYPE "Data and Trigger" CLK_SRC "/holy_core_only_clk_gen/clk_25" SYSTEM_ILA "Auto" } \
  [get_bd_nets pc_next] {PROBE_TYPE "Data and Trigger" CLK_SRC "/holy_core_only_clk_gen/clk_25" SYSTEM_ILA "Auto" } \
  ]
# ---------

# ---------
# Add BRAM
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property CONFIG.NUM_MI {3} [get_bd_cells smartconnect_0]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M02_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
# add some more..
copy_bd_objs /  [get_bd_cells {axi_bram_ctrl_0}]
copy_bd_objs /  [get_bd_cells {axi_bram_ctrl_1}]
set_property CONFIG.NUM_MI {5} [get_bd_cells smartconnect_0]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M03_AXI] [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins axi_bram_ctrl_2/S_AXI]
connect_bd_net [get_bd_pins axi_bram_ctrl_1/s_axi_aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
connect_bd_net [get_bd_pins axi_bram_ctrl_2/s_axi_aclk] [get_bd_pins holy_core_only_clk_gen/clk_25]
# BRAM inst automation
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_2/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_2/BRAM_PORTB]
endgroup
# ---------

# ---------
# CONNECT ALL PERIPHERALS RESETS
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_bram_ctrl_1/s_axi_aresetn]
connect_bd_net [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_bram_ctrl_2/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_gpio_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins smartconnect_0/aresetn]
# Tie non used resets
copy_bd_objs /  [get_bd_cells {xlconstant_0}]
connect_bd_net [get_bd_pins xlconstant_1/dout] [get_bd_pins top_0/trst_ni]
# ---------

################################################
# ETHERNET RELATED
################################################

################################################
# Final setup
################################################

# ---------
# MISC ADJUSTMENTS
# Const no intr
copy_bd_objs /  [get_bd_cells {xlconstant_1}]
set_property -dict [list \
  CONFIG.CONST_VAL {0} \
  CONFIG.CONST_WIDTH {2} \
] [get_bd_cells xlconstant_2]
connect_bd_net [get_bd_pins xlconstant_2/dout] [get_bd_pins top_0/irq_in]
# ---------

# ---------
# Assign SoC adresses, for this part, I'm using hc_lib/holy_core_soc.h taht contains some defaults addresses
assign_bd_address
# BRAMs
set_property offset 0x80000000 [get_bd_addr_segs {top_0/m_axi_lite/SEG_axi_bram_ctrl_0_Mem0}]
set_property offset 0x80002000 [get_bd_addr_segs {top_0/m_axi_lite/SEG_axi_bram_ctrl_1_Mem0}]
set_property offset 0x80004000 [get_bd_addr_segs {top_0/m_axi_lite/SEG_axi_bram_ctrl_2_Mem0}]
# GPIO
set_property offset 0x10010000 [get_bd_addr_segs {top_0/m_axi_lite/SEG_axi_gpio_0_Reg}]
# UART
set_property offset 0x10000000 [get_bd_addr_segs {top_0/m_axi_lite/SEG_axi_uartlite_0_Reg}]
# ---------

make_wrapper -files [get_files /tmp/HC_ETHERNET/holy_soc_project.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse /tmp/HC_ETHERNET/holy_soc_project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [current_fileset]

regenerate_bd_layout