# HOLY VIVADO SETUP
#
# TARGET BOARD : ARTY S7
#
# This scripts automates the integration of core in a basic SoC
#
# BRH 08/25

# Create a new project
create_project holy_soc_project /tmp/HOLY_SOC -part xc7s50csga324-1 -force
set_property board_part digilentinc.com:arty-s7-50:part0:1.1 [current_project]

# Add constraint file
add_files -fileset constrs_1 -norecurse ./3_perf_edition/fpga/arty_S7/constraints.xdc

# Add source files
add_files -norecurse {
    ./3_perf_edition/fpga/holy_top.v
    ./3_perf_edition/src/holy_data_cache.sv
    ./3_perf_edition/src/holy_no_cache.sv
    ./3_perf_edition/src/holy_instr_cache.sv
    ./3_perf_edition/src/control.sv
    ./3_perf_edition/src/reader.sv
    ./3_perf_edition/packages/axi_if.sv
    ./3_perf_edition/packages/axi_lite_if.sv
    ./3_perf_edition/packages/holy_core_pkg.sv
    ./3_perf_edition/src/regfile.sv
    ./3_perf_edition/src/external_req_arbitrer.sv
    ./3_perf_edition/src/alu.sv
    ./3_perf_edition/fpga/holy_top.sv
    ./3_perf_edition/src/holy_core.sv
    ./3_perf_edition/src/signext.sv
    ./3_perf_edition/src/load_store_decoder.sv
    ./3_perf_edition/src/csr_file.sv
    ./3_perf_edition/src/mul_div_unit.sv
    ./3_perf_edition/tb/holy_core/axi_if_convert.sv
    ./3_perf_edition/fpga/boot_rom.sv
    ./3_perf_edition/fpga/ROM/boot_rom.v
}

add_files [glob ./3_perf_edition/vendor/*.sv]
add_files [glob ./3_perf_edition/vendor/pulp-riscv-dbg/debug_rom/*.sv]
add_files [glob ./3_perf_edition/vendor/pulp-riscv-dbg/src/*.sv]

add_files [glob ./3_perf_edition/vendor/include/*.sv]
add_files [glob ./3_perf_edition/vendor/include/*.svh]
add_files [glob ./3_perf_edition/vendor/include/common_cells/*.svh]
add_files [glob ./3_perf_edition/vendor/include/axi/*.svh]
add_files [glob ./3_perf_edition/fpga/glue/*.sv]
# set_property include_dirs {./3_perf_edition/vendor/axi/include} [current_fileset]


# Update compile order
update_compile_order -fileset sources_1

# Create and configure the block design
create_bd_design "design_1"
create_bd_cell -type module -reference top top_0

# Add IP and configure settings
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0

# Apply board design automation rules
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/top_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}} [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

# Configure resets and clock interfaces
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Manual_Source {New External Port (ACTIVE_HIGH)}} [get_bd_pins clk_wiz/reset]
set_property name axi_reset [get_bd_ports reset_rtl]
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface {sys_clock (System Clock)} Manual_Source {Auto}} [get_bd_pins clk_wiz/clk_in1]

# Make pins external
make_bd_pins_external [get_bd_pins top_0/rst_n]
set_property name cpu_reset [get_bd_ports rst_n_0]

# Add JTAG to AXI IP
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {/clk_wiz/clk_out1 (100 MHz)} Clk_xbar {/clk_wiz/clk_out1 (100 MHz)} Master {/jtag_axi_0/M_AXI} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}} [get_bd_intf_pins jtag_axi_0/M_AXI]

# connect core's axi lite master to interconnect

set_property CONFIG.NUM_SI {3} [get_bd_cells axi_smc]
connect_bd_intf_net [get_bd_intf_pins top_0/m_axi_lite] [get_bd_intf_pins axi_smc/S02_AXI]

# chage clock period
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {143.688} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
] [get_bd_cells clk_wiz]

#add ILA

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_pins rst_clk_wiz_100M/ext_reset_in]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
                                                          [get_bd_intf_nets top_0_m_axi] {AXI_R_ADDRESS "Data and Trigger" AXI_R_DATA "Data and Trigger" AXI_W_ADDRESS "Data and Trigger" AXI_W_DATA "Data and Trigger" AXI_W_RESPONSE "Data and Trigger" CLK_SRC "/clk_wiz/clk_out1" SYSTEM_ILA "Auto" APC_EN "0" } \
                                                         ]

# make ILA get all probes
# add probes
set_property -dict [list \
  CONFIG.C_MON_TYPE {MIX} \
  CONFIG.C_NUM_MONITOR_SLOTS {2} \
  CONFIG.C_NUM_OF_PROBES {9} \
] [get_bd_cells system_ila_0]
set_property CONFIG.C_DATA_DEPTH {2048} [get_bd_cells system_ila_0]


# connect debugs
connect_bd_net [get_bd_pins top_0/pc] [get_bd_pins system_ila_0/probe0]
connect_bd_net [get_bd_pins top_0/pc_next] [get_bd_pins system_ila_0/probe1]
connect_bd_net [get_bd_pins top_0/instruction] [get_bd_pins system_ila_0/probe2]
connect_bd_net [get_bd_pins top_0/i_cache_stall] [get_bd_pins system_ila_0/probe3]
connect_bd_net [get_bd_pins top_0/d_cache_stall] [get_bd_pins system_ila_0/probe4]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins system_ila_0/probe5]

# Fix pin areset for CPU

connect_bd_net [get_bd_pins top_0/periph_rst_n] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]

#======================================
# BRH 05/25 New SoC with UART LITE

set_property CONFIG.NUM_SI {3} [get_bd_cells axi_smc]

connect_bd_intf_net [get_bd_intf_pins top_0/m_axi_lite] [get_bd_intf_pins axi_smc/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins system_ila_0/SLOT_1_AXI] [get_bd_intf_pins axi_smc/S02_AXI]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
set_property location {6 1695 448} [get_bd_cells axi_uartlite_0]

set_property CONFIG.NUM_MI {3} [get_bd_cells axi_smc]

connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins axi_smc/M02_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_intf_pins axi_uartlite_0/UART]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]


#======================================
# BRH 08/25 New SoC for v2 soc/software edition
# Starting from old base, the objectif is to add the clint, CLINT and basic peripherals
# including a way to load proggrams from an SD card

# Add source files
add_files -norecurse {
  ./3_perf_edition/src/holy_clint/holy_clint.sv
  ./3_perf_edition/src/holy_clint/holy_clint_wrapper.sv
  ./3_perf_edition/src/holy_clint/holy_clint_top.v
  ./3_perf_edition/src/holy_plic/holy_plic.sv
  ./3_perf_edition/src/holy_plic/holy_plic_wrapper.sv
  ./3_perf_edition/src/holy_plic/holy_plic_top.v
}
regenerate_bd_layout

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins xlconcat_0/In0]
set_property CONFIG.CONST_VAL {0} [get_bd_cells xlconstant_0]

# connect_bd_net [get_bd_pins axi_iic_0/gpo] [get_bd_pins xlconcat_0/In0]
#
# set_property CONFIG.NUM_PORTS {1} [get_bd_cells xlconcat_0]
#
# connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins holy_plic_top_0/irq_in]
# connect_bd_net [get_bd_pins holy_plic_top_0/rst_n] [get_bd_pins holy_clint_top_0/rst_n]
# connect_bd_net [get_bd_pins holy_clint_top_0/rst_n] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]
# regenerate_bd_layout
# delete_bd_objs [get_bd_nets axi_iic_0_gpo]
#
#
# connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In0]
# regenerate_bd_layout

# Add BRAM and debug

delete_bd_objs [get_bd_intf_nets axi_smc_M00_AXI] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTA] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTB] [get_bd_cells axi_bram_ctrl_0]
delete_bd_objs [get_bd_cells axi_bram_ctrl_0_bram]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1

apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi} Slave {/axi_bram_ctrl_1/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]

# artS S7 gpio (led)

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0

set_property CONFIG.GPIO_BOARD_INTERFACE {led_4bits} [get_bd_cells axi_gpio_0]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {led_4bits ( 4 LEDs ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_gpio_0/GPIO]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi_lite} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]

# add support for JTAG TAP

make_bd_pins_external  [get_bd_pins top_0/tck_i]
make_bd_pins_external  [get_bd_pins top_0/tms_i]
make_bd_pins_external  [get_bd_pins top_0/td_i]
make_bd_pins_external  [get_bd_pins top_0/td_o]
connect_bd_net [get_bd_pins top_0/trst_ni] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]
regenerate_bd_layout


# Addresses assignments

delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]

assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
set_property offset 0x0 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_bram_ctrl_0_Mem0}]
set_property range 32K [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_bram_ctrl_0_Mem0}]

assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] -force
set_property offset 0x8000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_bram_ctrl_1_Mem0}]
set_property range 32K [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_bram_ctrl_1_Mem0}]

assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -force
set_property offset 0x20000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_0_Reg}]

assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
set_property offset 0x10000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_uartlite_0_Reg}]

#irq config stuff
set_property CONFIG.NUM_PORTS {2} [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins top_0/irq_in]

# debug ILA UART + intr
set_property HDL_ATTRIBUTE.DEBUG true [get_bd_intf_nets {axi_uartlite_0_UART}]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
                                                          [get_bd_intf_nets axi_uartlite_0_UART] {NON_AXI_SIGNALS "Data and Trigger" CLK_SRC "/clk_wiz/clk_out1" SYSTEM_ILA "New" } \
                                                         ]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/clk_wiz/clk_out1 (25 MHz)} Freq {25} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins axi_uartlite_0/s_axi_aclk]


connect_bd_net [get_bd_pins system_ila_0/probe6] [get_bd_pins xlconcat_0/dout]


# ADD INCLUDES
set_property file_type "Verilog Header" [get_files ./3_perf_edition/vendor/include/prim_assert_dummy_macros.svh]
set_property is_global_include true [get_files ./3_perf_edition/vendor/include/prim_assert_dummy_macros.svh]


set_property file_type "Verilog Header" [get_files ./3_perf_edition/vendor/include/prim_assert.sv]
set_property is_global_include true [get_files ./3_perf_edition/vendor/include/prim_assert.sv]

set_property file_type "Verilog Header" [get_files ./3_perf_edition/vendor/include/prim_flop_macros.sv]
set_property is_global_include true [get_files ./3_perf_edition/vendor/include/prim_flop_macros.sv]

# ADD MIG FOR DDR
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_7series_0
apply_board_connection -board_interface "ddr3_sdram" -ip_intf "mig_7series_0/mig_ddr_interface" -diagram "design_1" 

delete_bd_objs [get_bd_nets sys_clk_i_1] [get_bd_ports sys_clk_i]
delete_bd_objs [get_bd_nets clk_ref_i_1] [get_bd_ports clk_ref_i]

set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {754.542} \
  CONFIG.CLKOUT1_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT2_JITTER {571.161} \
  CONFIG.CLKOUT2_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLKOUT3_JITTER {522.440} \
  CONFIG.CLKOUT3_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.CLKOUT3_USED {true} \
  CONFIG.CLK_OUT2_PORT {clk_100} \
  CONFIG.CLK_OUT3_PORT {clk_200} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {50.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {6} \
  CONFIG.MMCM_CLKOUT2_DIVIDE {3} \
  CONFIG.NUM_OUT_CLKS {3} \
] [get_bd_cells clk_wiz]
connect_bd_net [get_bd_pins clk_wiz/clk_100] [get_bd_pins mig_7series_0/sys_clk_i]
connect_bd_net [get_bd_pins mig_7series_0/clk_ref_i] [get_bd_pins clk_wiz/clk_200]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {/mig_7series_0/ui_clk (81 MHz)} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/jtag_axi_0/M_AXI} Slave {/mig_7series_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins mig_7series_0/S_AXI]

exec cp ./3_perf_edition/fpga/arty_S7/mig_HC.prj /tmp/HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/ip/design_1_mig_7series_0_0/mig_HC.prj
set_property CONFIG.XML_INPUT_FILE ./mig_HC.prj [get_bd_cells mig_7series_0]
set_property CONFIG.RESET_BOARD_INTERFACE {Custom} [get_bd_cells mig_7series_0]
set_property CONFIG.MIG_DONT_TOUCH_PARAM {Custom} [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM {ddr3_sdram} [get_bd_cells mig_7series_0]

# temp addresses for testing TODO : get rid of that
delete_bd_objs [get_bd_addr_segs top_0/m_axi/SEG_mig_7series_0_memaddr] [get_bd_addr_segs top_0/m_axi_lite/SEG_mig_7series_0_memaddr]
set_property range 64K [get_bd_addr_segs {jtag_axi_0/Data/SEG_mig_7series_0_memaddr}]
set_property offset 0x30000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_mig_7series_0_memaddr}]
assign_bd_address -target_address_space /top_0/m_axi [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
assign_bd_address -target_address_space /top_0/m_axi_lite [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force

# try to fix reset

disconnect_bd_net /rst_clk_wiz_100M_peripheral_aresetn [get_bd_pins top_0/trst_ni]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( System Reset ) } Manual_Source {Auto}}  [get_bd_pins mig_7series_0/sys_rst]
delete_bd_objs [get_bd_ports axi_reset]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] [get_bd_cells util_vector_logic_0]

connect_bd_net [get_bd_ports reset] [get_bd_pins util_vector_logic_0/Op1]
connect_bd_net [get_bd_pins util_vector_logic_0/Res] [get_bd_pins clk_wiz/reset]

disconnect_bd_net /rst_clk_wiz_100M_peripheral_aresetn [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins rst_clk_wiz_100M/interconnect_aresetn] [get_bd_pins axi_smc/aresetn]

delete_bd_objs [get_bd_cells system_ila_1]
set_property HDL_ATTRIBUTE.DEBUG false [get_bd_intf_nets { axi_uartlite_0_UART } ]

# Use MIG to repalce BRAM

# delete old BRAMS
delete_bd_objs [get_bd_intf_nets axi_smc_M01_AXI] [get_bd_intf_nets axi_bram_ctrl_1_BRAM_PORTA] [get_bd_intf_nets axi_bram_ctrl_1_BRAM_PORTB] [get_bd_cells axi_bram_ctrl_1]
delete_bd_objs [get_bd_intf_nets axi_smc_M00_AXI] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTA] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTB] [get_bd_cells axi_bram_ctrl_0]
delete_bd_objs [get_bd_cells axi_bram_ctrl_0_bram]
delete_bd_objs [get_bd_cells axi_bram_ctrl_1_bram]

# rewire smart connect correctly
set_property CONFIG.NUM_MI {3} [get_bd_cells axi_smc]
delete_bd_objs [get_bd_intf_nets axi_smc_M03_AXI] [get_bd_intf_nets axi_smc_M04_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins mig_7series_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
# assign addresses
delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
set_property offset 0x10000000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_uartlite_0_Reg}]
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -force
set_property offset 0x10010000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_0_Reg}]
assign_bd_address

# MISC
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1
connect_bd_net [get_bd_pins xlconstant_1/dout] [get_bd_pins top_0/trst_ni]
regenerate_bd_layout
set_property CONFIG.C_NUM_OF_PROBES {7} [get_bd_cells system_ila_0]

# Add I2C + set higher baud rate for UART
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_0
set_property location {7 2372 305} [get_bd_cells axi_iic_0]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {i2c ( I2C on J3 ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_iic_0/IIC]
delete_bd_objs [get_bd_nets xlconstant_0_dout]
delete_bd_objs [get_bd_cells xlconstant_0]
connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In0]
set_property CONFIG.C_BAUDRATE {128000} [get_bd_cells axi_uartlite_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi_lite} Slave {/axi_iic_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_iic_0/S_AXI]
validate_bd_design

set_property offset 0x10020000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_iic_0_Reg}]
delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]
undo
delete_bd_objs [get_bd_addr_segs top_0/m_axi_lite/SEG_axi_iic_0_Reg] [get_bd_addr_segs top_0/m_axi/SEG_axi_iic_0_Reg]
assign_bd_address

# ========================================
# ADD QSPI
# ========================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi_lite} Slave {/axi_quad_spi_0/AXI_LITE} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_quad_spi_0/AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {spi ( SPI connector J7 ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_quad_spi_0/SPI_0]
delete_bd_objs [get_bd_addr_segs top_0/m_axi/SEG_axi_quad_spi_0_Reg] [get_bd_addr_segs top_0/m_axi_lite/SEG_axi_quad_spi_0_Reg]
assign_bd_address -target_address_space /top_0/m_axi [get_bd_addr_segs axi_quad_spi_0/AXI_LITE/Reg] -force
set_property offset 0x10030000 [get_bd_addr_segs {top_0/m_axi/SEG_axi_quad_spi_0_Reg}]
assign_bd_address

# add clock for QSPI (and improve old clock speed)
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {729.396} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {30} \
  CONFIG.CLKOUT4_JITTER {888.832} \
  CONFIG.CLKOUT4_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {10} \
  CONFIG.CLKOUT4_USED {true} \
  CONFIG.CLK_OUT4_PORT {clk_10} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
  CONFIG.MMCM_CLKOUT3_DIVIDE {60} \
  CONFIG.NUM_OUT_CLKS {4} \
] [get_bd_cells clk_wiz]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/clk_wiz/clk_10 (10 MHz)} Freq {10} Ref_Clk0 {None} Ref_Clk1 {None} Ref_Clk2 {None}}  [get_bd_pins axi_quad_spi_0/ext_spi_clk]
set_property -dict [list \
  CONFIG.C_FIFO_DEPTH {256} \
  CONFIG.C_SCK_RATIO {2} \
] [get_bd_cells axi_quad_spi_0]
delete_bd_objs [get_bd_nets clk_wiz_clk_10]
connect_bd_net [get_bd_pins axi_quad_spi_0/ext_spi_clk] [get_bd_pins clk_wiz/clk_out1]


# Add GPIO shield pins
set_property -dict [list \
  CONFIG.C_INTERRUPT_PRESENT {1} \
  CONFIG.GPIO2_BOARD_INTERFACE {Custom} \
] [get_bd_cells axi_gpio_0]
set_property CONFIG.GPIO2_BOARD_INTERFACE {shield_dp0_dp9} [get_bd_cells axi_gpio_0]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {shield_dp0_dp9 ( Shield Pins 0 through 9 ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_gpio_0/GPIO2]

# misc
set_property -dict [list \
  CONFIG.CLKOUT4_USED {false} \
  CONFIG.MMCM_CLKOUT3_DIVIDE {1} \
  CONFIG.NUM_OUT_CLKS {3} \
] [get_bd_cells clk_wiz]
delete_bd_objs [get_bd_addr_segs jtag_axi_0/Data/SEG_axi_quad_spi_0_Reg]
assign_bd_address

#clock at 25
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {754.542} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} \
] [get_bd_cells clk_wiz]

# Validate + wrapper
assign_bd_address
validate_bd_design
update_compile_order -fileset sources_1
make_wrapper -files [get_files /tmp/HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse /tmp/HOLY_SOC/holy_soc_project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

regenerate_bd_layout


# generate synth, inmpl & bitstream
# launch_runs impl_1 -to_step write_bitstream -jobs 6
# set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]