# HOLY VIVADO SETUP
#
# TARGET BOARD : ARTY S7-50
#
# This scripts automates the integration of core in a basic SoC
#
# BRH 08/25

# Create a new project
create_project holy_soc_project /tmp/HOLY_SOC -part xc7s50csga324-1 -force
set_property board_part digilentinc.com:arty-s7-50:part0:1.1 [current_project]

# Add constraint file
add_files -fileset constrs_1 -norecurse ./2_soc_software_edition/fpga/arty_S7/constraints.xdc

# Add source files
add_files -norecurse {
    ./2_soc_software_edition/fpga/holy_wrapper.v
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
    ./2_soc_software_edition/fpga/axi_details.sv
    ./2_soc_software_edition/src/holy_core.sv
    ./2_soc_software_edition/src/signext.sv
    ./2_soc_software_edition/src/load_store_decoder.sv
    ./2_soc_software_edition/src/csr_file.sv
}

# Update compile order
update_compile_order -fileset sources_1

# Create and configure the block design
create_bd_design "design_1"
create_bd_cell -type module -reference holy_wrapper holy_wrapper_0

# Add IP and configure settings
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
endgroup

# Apply board design automation rules
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/holy_wrapper_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}} [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config {Clk {New Clocking Wizard} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}} [get_bd_pins holy_wrapper_0/clk]
endgroup

# Regenerate layout and connect nets
regenerate_bd_layout
delete_bd_objs [get_bd_nets clk_wiz_1_clk_out1] [get_bd_cells clk_wiz_1]
connect_bd_net [get_bd_pins holy_wrapper_0/clk] [get_bd_pins clk_wiz/clk_out1]

# Configure resets and clock interfaces
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Manual_Source {New External Port (ACTIVE_HIGH)}} [get_bd_pins clk_wiz/reset]
set_property name axi_reset [get_bd_ports reset_rtl]
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface {sys_clock (System Clock)} Manual_Source {Auto}} [get_bd_pins clk_wiz/clk_in1]
connect_bd_net [get_bd_ports axi_reset] [get_bd_pins holy_wrapper_0/aresetn]
endgroup

# Make pins external
startgroup
make_bd_pins_external [get_bd_pins holy_wrapper_0/rst_n]
set_property name cpu_reset [get_bd_ports rst_n_0]
endgroup

# Add JTAG to AXI IP
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag_axi_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {/clk_wiz/clk_out1 (100 MHz)} Clk_xbar {/clk_wiz/clk_out1 (100 MHz)} Master {/jtag_axi_0/M_AXI} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}} [get_bd_intf_pins jtag_axi_0/M_AXI]
endgroup

# chage clock period
startgroup
set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {143.688} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {50} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {20.000} \
] [get_bd_cells clk_wiz]
endgroup


# Save the block design
save_bd_design

# Clean up existing address segments to avoid overlaps
delete_bd_objs [get_bd_addr_segs]

#add ILA

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_pins rst_clk_wiz_100M/ext_reset_in]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
                                                          [get_bd_intf_nets holy_wrapper_0_m_axi] {AXI_R_ADDRESS "Data and Trigger" AXI_R_DATA "Data and Trigger" AXI_W_ADDRESS "Data and Trigger" AXI_W_DATA "Data and Trigger" AXI_W_RESPONSE "Data and Trigger" CLK_SRC "/clk_wiz/clk_out1" SYSTEM_ILA "Auto" APC_EN "0" } \
                                                         ]
endgroup

# make ILA get all probes
# add probes
startgroup
set_property -dict [list \
  CONFIG.C_MON_TYPE {MIX} \
  CONFIG.C_NUM_MONITOR_SLOTS {2} \
  CONFIG.C_NUM_OF_PROBES {20} \
] [get_bd_cells system_ila_0]
set_property CONFIG.C_DATA_DEPTH {2048} [get_bd_cells system_ila_0]
endgroup


# connect debugs
connect_bd_net [get_bd_pins holy_wrapper_0/pc] [get_bd_pins system_ila_0/probe0]
connect_bd_net [get_bd_pins holy_wrapper_0/pc_next] [get_bd_pins system_ila_0/probe1]
connect_bd_net [get_bd_pins holy_wrapper_0/instruction] [get_bd_pins system_ila_0/probe2]
connect_bd_net [get_bd_pins holy_wrapper_0/i_cache_stall] [get_bd_pins system_ila_0/probe3]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_stall] [get_bd_pins system_ila_0/probe4]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins system_ila_0/probe5]

# Fix pin areset for CPU

disconnect_bd_net /reset_rtl_1 [get_bd_pins holy_wrapper_0/aresetn]
connect_bd_net [get_bd_pins holy_wrapper_0/aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]

#======================================
# BRH 05/25 New SoC with UART LITE

startgroup
set_property CONFIG.NUM_SI {3} [get_bd_cells axi_smc]
endgroup

connect_bd_intf_net [get_bd_intf_pins holy_wrapper_0/m_axi_lite] [get_bd_intf_pins axi_smc/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins system_ila_0/SLOT_1_AXI] [get_bd_intf_pins axi_smc/S02_AXI]

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
endgroup
set_property location {6 1695 448} [get_bd_cells axi_uartlite_0]

startgroup
set_property CONFIG.NUM_MI {3} [get_bd_cells axi_smc]
endgroup

connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins axi_smc/M02_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_intf_pins axi_uartlite_0/UART]

connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aclk] [get_bd_pins clk_wiz/clk_out1]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]

delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]
assign_bd_address

#======================================
# BRH 06/25 New SoC with I2C

# add IIC AXI ip and automatically add IIC ongoing pins
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_0
endgroup
set_property location {6 1876 618} [get_bd_cells axi_iic_0]
apply_bd_automation -rule xilinx.com:bd_rule:board -config { Board_Interface {Custom} Manual_Source {Auto}}  [get_bd_intf_pins axi_iic_0/IIC]

# Connect AXI IIC TO SMC, rst and clk
startgroup
set_property CONFIG.NUM_MI {4} [get_bd_cells axi_smc]
endgroup
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins axi_iic_0/S_AXI]
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]
connect_bd_net [get_bd_pins axi_iic_0/s_axi_aclk] [get_bd_pins clk_wiz/clk_out1]

# add ILA and configure it
set_property HDL_ATTRIBUTE.DEBUG true [get_bd_intf_nets {axi_iic_0_IIC}]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
                                                          [get_bd_intf_nets axi_iic_0_IIC] {NON_AXI_SIGNALS "Data and Trigger" CLK_SRC "/clk_wiz/clk_out1" SYSTEM_ILA "New" } \
                                                         ]

set_property location {6 1997 812} [get_bd_cells system_ila_1]
startgroup
set_property CONFIG.C_DATA_DEPTH {65536} [get_bd_cells system_ila_1]
endgroup
save_bd_design
regenerate_bd_layout

# addressing for AXI IIC
assign_bd_address
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_iic_0_Reg}]
set_property offset 0x3000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_iic_0_Reg}]
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_iic_0_Reg}]
set_property offset 0x3000 [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_iic_0_Reg}]
set_property range 2K [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_iic_0_Reg}]
set_property offset 0x3000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_iic_0_Reg}]
save_bd_design


#======================================
# BRH 08/25 New SoC for v2 soc/software edition
# Starting from old base, the objectif is to add the clint, CLINT and basic peripherals
# including a way to load proggrams from an SD card

# Add source files
add_files -norecurse {
  ./2_soc_software_edition/src/holy_clint/holy_clint.sv
  ./2_soc_software_edition/src/holy_clint/holy_clint_wrapper.sv
  ./2_soc_software_edition/src/holy_clint/holy_clint_top.v
  ./2_soc_software_edition/src/holy_plic/holy_plic.sv
  ./2_soc_software_edition/src/holy_plic/holy_plic_wrapper.sv
  ./2_soc_software_edition/src/holy_plic/holy_plic_top.v
}

update_compile_order -fileset sources_1
create_bd_cell -type module -reference holy_clint_top holy_clint_top_0
create_bd_cell -type module -reference holy_plic_top holy_plic_top_0

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (50 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (50 MHz)} Master {/holy_wrapper_0/m_axi_lite} Slave {/holy_clint_top_0/s_axi} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins holy_clint_top_0/s_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (50 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (50 MHz)} Master {/holy_wrapper_0/m_axi_lite} Slave {/holy_plic_top_0/s_axi} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins holy_plic_top_0/s_axi]
endgroup

startgroup
set_property CONFIG.NUM_IRQS {1} [get_bd_cells holy_plic_top_0]
endgroup

connect_bd_net [get_bd_pins holy_clint_top_0/timer_irq] [get_bd_pins holy_wrapper_0/timer_irq]
connect_bd_net [get_bd_pins holy_clint_top_0/soft_irq] [get_bd_pins holy_wrapper_0/soft_irq]
connect_bd_net [get_bd_pins holy_plic_top_0/ext_irq_o] [get_bd_pins holy_wrapper_0/ext_irq]
regenerate_bd_layout

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
endgroup

connect_bd_net [get_bd_pins axi_iic_0/gpo] [get_bd_pins xlconcat_0/In0]
startgroup
set_property CONFIG.NUM_PORTS {1} [get_bd_cells xlconcat_0]
endgroup
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins holy_plic_top_0/irq_in]
connect_bd_net [get_bd_pins holy_plic_top_0/rst_n] [get_bd_pins holy_clint_top_0/rst_n]
connect_bd_net [get_bd_pins holy_clint_top_0/rst_n] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]
regenerate_bd_layout
delete_bd_objs [get_bd_nets axi_iic_0_gpo]
startgroup
endgroup
connect_bd_net [get_bd_pins axi_iic_0/iic2intc_irpt] [get_bd_pins xlconcat_0/In0]
regenerate_bd_layout

# Add BRAM and debug

delete_bd_objs [get_bd_intf_nets axi_smc_M00_AXI] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTA] [get_bd_intf_nets axi_bram_ctrl_0_BRAM_PORTB] [get_bd_cells axi_bram_ctrl_0]
delete_bd_objs [get_bd_cells axi_bram_ctrl_0_bram]

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
endgroup

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_1
endgroup

startgroup
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (50 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (50 MHz)} Master {/holy_wrapper_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto" }  [get_bd_intf_pins axi_bram_ctrl_1/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz/clk_out1 (50 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz/clk_out1 (50 MHz)} Master {/holy_wrapper_0/m_axi} Slave {/axi_bram_ctrl_1/S_AXI} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins axi_bram_ctrl_1/S_AXI]
endgroup

# Addresses assignments

delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]
assign_bd_address -target_address_space /holy_wrapper_0/m_axi [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force

assign_bd_address -target_address_space /holy_wrapper_0/m_axi [get_bd_addr_segs axi_bram_ctrl_1/S_AXI/Mem0] -force
set_property offset 0 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_0_Mem0}]
set_property range 32K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_0_Mem0}]

set_property offset 0x8000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_1_Mem0}]
set_property range 32K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_1_Mem0}]

assign_bd_address

startgroup
set_property CONFIG.BASE_ADDR {0x40000000} [get_bd_cells holy_clint_top_0]
endgroup
startgroup
set_property -dict [list \
  CONFIG.BASE_ADDR {0x80000000} \
  CONFIG.NUM_IRQS {2} \
] [get_bd_cells holy_plic_top_0]
endgroup

#irq config stuff
startgroup
set_property CONFIG.NUM_PORTS {2} [get_bd_cells xlconcat_0]
endgroup
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins xlconcat_0/In1]

# debug ILA UART + intr
set_property HDL_ATTRIBUTE.DEBUG true [get_bd_intf_nets {axi_uartlite_0_UART}]
apply_bd_automation -rule xilinx.com:bd_rule:debug -dict [list \
                                                          [get_bd_intf_nets axi_uartlite_0_UART] {NON_AXI_SIGNALS "Data and Trigger" CLK_SRC "/clk_wiz/clk_out1" SYSTEM_ILA "New" } \
                                                         ]
startgroup
set_property CONFIG.C_MON_TYPE {MIX} [get_bd_cells system_ila_2]
endgroup
connect_bd_net [get_bd_pins system_ila_2/probe0] [get_bd_pins axi_uartlite_0/interrupt]

startgroup
set_property CONFIG.C_DATA_DEPTH {65536} [get_bd_cells system_ila_2]
endgroup

# add itrs to IIC ila

startgroup
set_property CONFIG.C_MON_TYPE {MIX} [get_bd_cells system_ila_1]
endgroup
connect_bd_net [get_bd_pins axi_iic_0/gpo] [get_bd_pins system_ila_1/probe0]

# add itrs to main ILA

startgroup
set_property CONFIG.C_NUM_OF_PROBES {10} [get_bd_cells system_ila_0]
endgroup
connect_bd_net [get_bd_pins system_ila_0/probe6] [get_bd_pins holy_clint_top_0/timer_irq]
connect_bd_net [get_bd_pins system_ila_0/probe7] [get_bd_pins holy_clint_top_0/soft_irq]
connect_bd_net [get_bd_pins system_ila_0/probe8] [get_bd_pins holy_plic_top_0/ext_irq_o]
connect_bd_net [get_bd_pins system_ila_0/probe9] [get_bd_pins xlconcat_0/dout]

# slight corrections

delete_bd_objs [get_bd_cells system_ila_2]
delete_bd_objs [get_bd_nets axi_iic_0_gpo] [get_bd_cells system_ila_1]

startgroup
set_property HDL_ATTRIBUTE.DEBUG false [get_bd_intf_nets { axi_iic_0_IIC } ]
endgroup
startgroup
set_property HDL_ATTRIBUTE.DEBUG false [get_bd_intf_nets { axi_uartlite_0_UART } ]
endgroup

# Validate + wrapper
validate_bd_design
update_compile_order -fileset sources_1
make_wrapper -files [get_files /tmp/HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse /tmp/HOLY_SOC/holy_soc_project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# add even more BRAM... (total 128kB)

# generate synth, inmpl & bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 6