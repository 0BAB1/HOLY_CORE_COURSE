# HOLY VIVADO SETUP
#
# TARGET BOARD : ARTY S7
#
# This scripts automates the integration of core in a basic SoC
#
# BRH 10/25

# Create a new project
create_project holy_soc_project /tmp/HOLY_SOC -part xc7s50csga324-1 -force
set_property board_part digilentinc.com:arty-s7-50:part0:1.1 [current_project]

# Add constraint file
add_files -fileset constrs_1 -norecurse ./2_soc_software_edition/fpga/arty_S7/constraints.xdc

# Add source files
add_files -norecurse {
    ./2_soc_software_edition/fpga/holy_top.v
    ./2_soc_software_edition/src/holy_data_cache.sv
    ./2_soc_software_edition/src/holy_data_no_cache.sv
    ./2_soc_software_edition/src/holy_cache.sv
    ./2_soc_software_edition/src/control.sv
    ./2_soc_software_edition/src/reader.sv
    ./2_soc_software_edition/packages/axi_if.sv
    ./2_soc_software_edition/packages/axi_lite_if.sv
    ./2_soc_software_edition/packages/holy_core_pkg.sv
    ./2_soc_software_edition/src/regfile.sv
    ./2_soc_software_edition/src/external_req_arbitrer.sv
    ./2_soc_software_edition/src/alu.sv
    ./2_soc_software_edition/fpga/holy_top.sv
    ./2_soc_software_edition/src/holy_core.sv
    ./2_soc_software_edition/src/signext.sv
    ./2_soc_software_edition/src/load_store_decoder.sv
    ./2_soc_software_edition/src/csr_file.sv
    ./2_soc_software_edition/tb/holy_core/axi_if_convert.sv
}

add_files [glob ./2_soc_software_edition/vendor/*.sv]
add_files [glob ./2_soc_software_edition/vendor/pulp-riscv-dbg/debug_rom/*.sv]
add_files [glob ./2_soc_software_edition/vendor/pulp-riscv-dbg/src/*.sv]

add_files [glob ./2_soc_software_edition/vendor/include/*.sv]
add_files [glob ./2_soc_software_edition/vendor/include/*.svh]
add_files [glob ./2_soc_software_edition/vendor/include/common_cells/*.svh]
add_files [glob ./2_soc_software_edition/vendor/include/axi/*.svh]
add_files [glob ./2_soc_software_edition/fpga/glue/*.sv]
# set_property include_dirs {./2_soc_software_edition/vendor/axi/include} [current_fileset]

# Update compile order
update_compile_order -fileset sources_1

# Create and configure the block design
create_bd_design "design_1"
create_bd_cell -type module -reference top top_0

# CLOCKING WIZARD + RESET/CLK IN (AUTOMATION)
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {ddr_clock ( DDR Clock ) } Manual_Source {New External Port (ACTIVE_LOW)}}  [get_bd_pins clk_wiz_0/clk_in1]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( System Reset ) } Manual_Source {New External Port (ACTIVE_HIGH)}}  [get_bd_pins clk_wiz_0/reset]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins top_0/clk]

# SET FREQUENCIES
# out1    => for holy core and peripherals
# 100MHz  => for MIG's sys clk 
# 200MHz  => for MIG solid reference
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {175.402} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {25.000} \
  CONFIG.CLKOUT2_JITTER {130.958} \
  CONFIG.CLKOUT2_PHASE_ERROR {98.575} \
  CONFIG.CLKOUT2_USED {true} \
  CONFIG.CLKOUT3_JITTER {114.829} \
  CONFIG.CLKOUT3_PHASE_ERROR {98.575} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.CLKOUT3_USED {true} \
  CONFIG.CLK_OUT2_PORT {clk_100} \
  CONFIG.CLK_OUT3_PORT {clk_200} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {40.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {10} \
  CONFIG.MMCM_CLKOUT2_DIVIDE {5} \
  CONFIG.NUM_OUT_CLKS {3} \
] [get_bd_cells clk_wiz_0]

# CPU RESET
make_bd_pins_external  [get_bd_pins top_0/rst_n]
set_property name cpu_reset [get_bd_ports rst_n_0]

# DDR MIG INTERFACE
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 mig_7series_0
apply_board_connection -board_interface "ddr3_sdram" -ip_intf "mig_7series_0/mig_ddr_interface" -diagram "design_1"
endgroup
# mig rstn
delete_bd_objs [get_bd_nets reset_0_1] [get_bd_ports reset_0]

delete_bd_objs [get_bd_nets sys_clk_i_1] [get_bd_ports sys_clk_i]
delete_bd_objs [get_bd_nets clk_ref_i_1] [get_bd_ports clk_ref_i]
connect_bd_net [get_bd_pins clk_wiz_0/clk_100] [get_bd_pins mig_7series_0/sys_clk_i]
connect_bd_net [get_bd_pins clk_wiz_0/clk_200] [get_bd_pins mig_7series_0/clk_ref_i]

connect_bd_net [get_bd_pins mig_7series_0/sys_rst] [get_bd_pins rst_clk_wiz_0_25M/peripheral_aresetn]

cp ./2_soc_software_edition/fpga/arty_S7/mig_HC.prj /tmp/HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/ip/design_1_mig_7series_0_0/mig_HC.prj
set_property CONFIG.XML_INPUT_FILE ./mig_HC.prj [get_bd_cells mig_7series_0]
set_property CONFIG.RESET_BOARD_INTERFACE {Custom} [get_bd_cells mig_7series_0]
set_property CONFIG.MIG_DONT_TOUCH_PARAM {Custom} [get_bd_cells mig_7series_0]
set_property CONFIG.BOARD_MIG_PARAM {ddr3_sdram} [get_bd_cells mig_7series_0]

# CREATE AXI INTERCONNECT
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz_0/clk_out1 (25 MHz)} Clk_slave {/mig_7series_0/ui_clk (81 MHz)} Clk_xbar {/clk_wiz_0/clk_out1 (25 MHz)} Master {/top_0/m_axi} Slave {/mig_7series_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins mig_7series_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {reset ( System Reset ) } Manual_Source {Auto}}  [get_bd_pins mig_7series_0/sys_rst]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz_0/clk_out1 (25 MHz)} Clk_slave {/mig_7series_0/ui_clk (81 MHz)} Clk_xbar {/clk_wiz_0/clk_out1 (25 MHz)} Master {/top_0/m_axi_lite} Slave {/mig_7series_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins top_0/m_axi_lite]
endgroup

# Add JTAG to AXI IP
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz_0/clk_out1 (25 MHz)} Clk_slave {/mig_7series_0/ui_clk (81 MHz)} Clk_xbar {/clk_wiz_0/clk_out1 (25 MHz)} Master {/jtag_axi_0/M_AXI} Slave {/mig_7series_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins jtag_axi_0/M_AXI]
endgroup

#add ILA
create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 system_ila_0
connect_bd_net [get_bd_pins system_ila_0/clk] [get_bd_pins clk_wiz_0/clk_out1]

# make ILA get all probes
# add probes
startgroup
set_property -dict [list \
  CONFIG.C_MON_TYPE {MIX} \
  CONFIG.C_NUM_MONITOR_SLOTS {2} \
  CONFIG.C_NUM_OF_PROBES {9} \
] [get_bd_cells system_ila_0]
set_property CONFIG.C_DATA_DEPTH {2048} [get_bd_cells system_ila_0]
endgroup


# connect debugs
connect_bd_net [get_bd_pins top_0/pc] [get_bd_pins system_ila_0/probe0]
connect_bd_net [get_bd_pins top_0/pc_next] [get_bd_pins system_ila_0/probe1]
connect_bd_net [get_bd_pins top_0/instruction] [get_bd_pins system_ila_0/probe2]
connect_bd_net [get_bd_pins top_0/i_cache_stall] [get_bd_pins system_ila_0/probe3]
connect_bd_net [get_bd_pins top_0/d_cache_stall] [get_bd_pins system_ila_0/probe4]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins system_ila_0/probe5]
connect_bd_net [get_bd_pins top_0/i_cache_state] [get_bd_pins system_ila_0/probe7]
connect_bd_net [get_bd_pins top_0/i_cache_stall] [get_bd_pins system_ila_0/probe8]

# Fix pin areset for CPU
connect_bd_net [get_bd_pins top_0/periph_rst_n] [get_bd_pins rst_clk_wiz_0_25M/peripheral_aresetn]

#======================================
# BRH 05/25 New SoC with UART LITE
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
endgroup

startgroup
set_property CONFIG.NUM_MI {2} [get_bd_cells axi_smc]
endgroup

connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins axi_smc/M01_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_intf_pins axi_uartlite_0/UART]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_0_25M/peripheral_aresetn]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/clk_wiz_0/clk_out1 (25 MHz)} Freq {25} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins axi_uartlite_0/s_axi_aclk]

#======================================
# BRH 08/25 New SoC for v2 soc/software edition
# Starting from old base, the objectif is to add the clint, CLINT and basic peripherals

# Add source files
add_files -norecurse {
  ./2_soc_software_edition/src/holy_clint/holy_clint.sv
  ./2_soc_software_edition/src/holy_clint/holy_clint_wrapper.sv
  ./2_soc_software_edition/src/holy_clint/holy_clint_top.v
  ./2_soc_software_edition/src/holy_plic/holy_plic.sv
  ./2_soc_software_edition/src/holy_plic/holy_plic_wrapper.sv
  ./2_soc_software_edition/src/holy_plic/holy_plic_top.v
}
regenerate_bd_layout

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
endgroup

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
endgroup
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins xlconcat_0/In0]
startgroup
set_property CONFIG.CONST_VAL {0} [get_bd_cells xlconstant_0]
endgroup

# artS S7 gpio (led)

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
endgroup

startgroup
set_property CONFIG.GPIO_BOARD_INTERFACE {led_4bits} [get_bd_cells axi_gpio_0]
endgroup

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {led_4bits ( 4 LEDs ) } Manual_Source {Auto}}  [get_bd_intf_pins axi_gpio_0/GPIO]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (25 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (25 MHz)} Master {/top_0/m_axi_lite} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
endgroup

#irq config stuff
startgroup
set_property CONFIG.NUM_PORTS {2} [get_bd_cells xlconcat_0]
endgroup
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins top_0/irq_in]
connect_bd_net [get_bd_pins system_ila_0/probe6] [get_bd_pins xlconcat_0/dout]


# add support for JTAG TAP
startgroup
make_bd_pins_external  [get_bd_pins top_0/tck_i]
endgroup
startgroup
make_bd_pins_external  [get_bd_pins top_0/tms_i]
endgroup
startgroup
make_bd_pins_external  [get_bd_pins top_0/td_i]
endgroup
startgroup
make_bd_pins_external  [get_bd_pins top_0/td_o]
endgroup
connect_bd_net [get_bd_pins top_0/trst_ni] [get_bd_pins rst_clk_wiz_0_25M/peripheral_aresetn]


# ADD INCLUDES
set_property file_type "Verilog Header" [get_files ./2_soc_software_edition/vendor/include/prim_assert_dummy_macros.svh]
set_property is_global_include true [get_files ./2_soc_software_edition/vendor/include/prim_assert_dummy_macros.svh]
set_property file_type "Verilog Header" [get_files ./2_soc_software_edition/vendor/include/prim_assert.sv]
set_property is_global_include true [get_files ./2_soc_software_edition/vendor/include/prim_assert.sv]
set_property file_type "Verilog Header" [get_files ./2_soc_software_edition/vendor/include/prim_flop_macros.sv]
set_property is_global_include true [get_files ./2_soc_software_edition/vendor/include/prim_flop_macros.sv]

# ADDRESS ASSIGNEMNTS
delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]

# DDR3 DRAM : from 0x0 spreading over 256MB
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs mig_7series_0/memmap/memaddr] -force
set_property offset 0x0 [get_bd_addr_segs {jtag_axi_0/Data/SEG_mig_7series_0_memaddr}]
# Assign extrnal peripherals
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] -force
assign_bd_address -target_address_space /jtag_axi_0/Data [get_bd_addr_segs axi_uartlite_0/S_AXI/Reg] -force
set_property offset 0x10000000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_uartlite_0_Reg}]
set_property offset 0x10600000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_0_Reg}]
assign_bd_address

# MISC
# dumb*ss reset
delete_bd_objs [get_bd_nets reset_0_1] [get_bd_ports reset_0]
connect_bd_net [get_bd_pins mig_7series_0/sys_rst] [get_bd_pins rst_clk_wiz_0_25M/peripheral_aresetn]
# dumb*ss clock
startgroup
set_property -dict [list \
  CONFIG.CLKIN1_JITTER_PS {833.33} \
  CONFIG.CLKOUT1_JITTER {754.542} \
  CONFIG.CLKOUT1_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT2_JITTER {571.161} \
  CONFIG.CLKOUT2_PHASE_ERROR {613.025} \
  CONFIG.CLKOUT3_JITTER {522.440} \
  CONFIG.CLKOUT3_PHASE_ERROR {613.025} \
  CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {50.000} \
  CONFIG.MMCM_CLKIN1_PERIOD {83.333} \
  CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {6} \
  CONFIG.MMCM_CLKOUT2_DIVIDE {3} \
] [get_bd_cells clk_wiz_0]
endgroup
delete_bd_objs [get_bd_nets ddr_clock_1] [get_bd_ports ddr_clock]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {sys_clock ( System Clock ) } Manual_Source {Auto}}  [get_bd_pins clk_wiz_0/clk_in1]

# Validate + wrapper
assign_bd_address
validate_bd_design
update_compile_order -fileset sources_1
make_wrapper -files [get_files /tmp/HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse /tmp/HOLY_SOC/holy_soc_project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# generate synth, inmpl & bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 6