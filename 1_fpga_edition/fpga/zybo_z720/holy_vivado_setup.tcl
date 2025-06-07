# HOLY VIVADO SETUP
#
# TARGET BOARD : ZYBO Z7-20
#
# This scripts automates the integration of core in a basic SoC with a connection to the LEDs and Some BRAM.0
# Afer this script is done, it launches synth, impl and generates a bitstream. Check the "example programs"
# folder to load a program.
# Please run it from the ROOT of the repo
#
# BRH 12/24
# Updated 05/25 by BRH : added csr support
# Updated 05/25 by BRH : added axi_lite

# Create a new project
create_project holy_soc_project ./HOLY_SOC -part xc7z020clg400-1 -force
set_property board_part digilentinc.com:zybo-z7-20:part0:1.2 [current_project]

# Add constraint file
add_files -fileset constrs_1 -norecurse ./1_fpga_edition/fpga/zybo_z720/constraints.xdc

# Add source files
add_files -norecurse {
    ./1_fpga_edition/fpga/holy_wrapper.v
    ./1_fpga_edition/src/holy_data_cache.sv
    ./1_fpga_edition/src/holy_cache.sv
    ./1_fpga_edition/src/control.sv
    ./1_fpga_edition/src/reader.sv
    ./1_fpga_edition/packages/axi_if.sv
    ./1_fpga_edition/packages/axi_lite_if.sv
    ./1_fpga_edition/packages/holy_core_pkg.sv
    ./1_fpga_edition/src/regfile.sv
    ./1_fpga_edition/src/external_req_arbitrer.sv
    ./1_fpga_edition/src/alu.sv
    ./1_fpga_edition/fpga/axi_details.sv
    ./1_fpga_edition/src/holy_core.sv
    ./1_fpga_edition/src/signext.sv
    ./1_fpga_edition/src/load_store_decoder.sv
    ./1_fpga_edition/src/csr_file.sv
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
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property CONFIG.GPIO_BOARD_INTERFACE {leds_4bits} [get_bd_cells axi_gpio_0]
endgroup

# Apply board design automation rules
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA]
apply_bd_automation -rule xilinx.com:bd_rule:bram_cntlr -config {BRAM "Auto"} [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTB]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/holy_wrapper_0/m_axi} Slave {/axi_bram_ctrl_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}} [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:board -config {Board_Interface {leds_4bits (4 LEDs)} Manual_Source {Auto}} [get_bd_intf_pins axi_gpio_0/GPIO]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/holy_wrapper_0/m_axi} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}} [get_bd_intf_pins axi_gpio_0/S_AXI]
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
set_property CONFIG.C_DATA_DEPTH {4096} [get_bd_cells system_ila_0]
endgroup


# connect
connect_bd_net [get_bd_pins holy_wrapper_0/pc] [get_bd_pins system_ila_0/probe0]
connect_bd_net [get_bd_pins holy_wrapper_0/pc_next] [get_bd_pins system_ila_0/probe1]
connect_bd_net [get_bd_pins holy_wrapper_0/instruction] [get_bd_pins system_ila_0/probe2]
connect_bd_net [get_bd_pins holy_wrapper_0/i_cache_state] [get_bd_pins system_ila_0/probe3]
connect_bd_net [get_bd_pins holy_wrapper_0/i_cache_stall] [get_bd_pins system_ila_0/probe4]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_stall] [get_bd_pins system_ila_0/probe5]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_stall] [get_bd_pins system_ila_0/probe6]
undo
connect_bd_net [get_bd_pins system_ila_0/probe6] [get_bd_pins holy_wrapper_0/i_cache_set_ptr]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_set_ptr] [get_bd_pins system_ila_0/probe7]
connect_bd_net [get_bd_pins holy_wrapper_0/i_next_set_ptr] [get_bd_pins system_ila_0/probe8]
connect_bd_net [get_bd_pins holy_wrapper_0/d_next_set_ptr] [get_bd_pins system_ila_0/probe9]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins system_ila_0/probe10]
connect_bd_net [get_bd_pins holy_wrapper_0/csr_flush_order] [get_bd_pins system_ila_0/probe11]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_state] [get_bd_pins system_ila_0/probe12]
connect_bd_net [get_bd_pins holy_wrapper_0/pc_source] [get_bd_pins system_ila_0/probe13]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_seq_stall] [get_bd_pins system_ila_0/probe14]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_comb_stall] [get_bd_pins system_ila_0/probe15]
connect_bd_net [get_bd_pins holy_wrapper_0/d_cache_next_state] [get_bd_pins system_ila_0/probe16]
connect_bd_net [get_bd_pins holy_wrapper_0/mem_read] [get_bd_pins system_ila_0/probe17]
connect_bd_net [get_bd_pins holy_wrapper_0/mem_byte_en] [get_bd_pins system_ila_0/probe18]
connect_bd_net [get_bd_pins holy_wrapper_0/wb_data] [get_bd_pins system_ila_0/probe19]

# Add axi converted for gpio

delete_bd_objs [get_bd_intf_nets axi_smc_M01_AXI]
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter:2.1 axi_protocol_convert_0
endgroup
set_property location {3.5 1016 214} [get_bd_cells axi_protocol_convert_0]
connect_bd_intf_net [get_bd_intf_pins axi_protocol_convert_0/M_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_protocol_convert_0/S_AXI] [get_bd_intf_pins axi_smc/M01_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config { Clk {/clk_wiz/clk_out1 (50 MHz)} Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}}  [get_bd_pins axi_protocol_convert_0/aclk]
regenerate_bd_layout

# Manage the addresses
assign_bd_address

set_property offset 0 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_0_Mem0}]
set_property offset 0x40000000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]
set_property range 4K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]
set_property offset 0x0002000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]

delete_bd_objs [get_bd_addr_segs jtag_axi_0/Data/SEG_axi_bram_ctrl_0_Mem0] [get_bd_addr_segs jtag_axi_0/Data/SEG_axi_gpio_0_Reg]
assign_bd_address

# Fix pin areset for CPU

disconnect_bd_net /reset_rtl_1 [get_bd_pins holy_wrapper_0/aresetn]
connect_bd_net [get_bd_pins holy_wrapper_0/aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]

#======================================
# BRH 05/25 New SoC with UART LITE

delete_bd_objs [get_bd_intf_nets axi_smc_M01_AXI] [get_bd_intf_nets axi_protocol_convert_0_M_AXI] [get_bd_cells axi_protocol_convert_0]

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

connect_bd_intf_net [get_bd_intf_pins axi_gpio_0/S_AXI] [get_bd_intf_pins axi_smc/M01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_uartlite_0/S_AXI] [get_bd_intf_pins axi_smc/M02_AXI]

apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {Auto}}  [get_bd_intf_pins axi_uartlite_0/UART]

connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aclk] [get_bd_pins clk_wiz/clk_out1]
connect_bd_net [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins rst_clk_wiz_100M/peripheral_aresetn]

delete_bd_objs [get_bd_addr_segs] [get_bd_addr_segs -excluded]
assign_bd_address

# all manual address reassignements...
set_property offset 0x40600000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_uartlite_0_Reg}]
set_property offset 0 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_bram_ctrl_0_Mem0}]
set_property range 4K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]
set_property range 4K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_uartlite_0_Reg}]
set_property offset 0x2000 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_gpio_0_Reg}]
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_uartlite_0_Reg}]
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_gpio_0_Reg}]
set_property range 2K [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_uartlite_0_Reg}]
set_property range 2K [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_0_Reg}]
set_property range 2K [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_uartlite_0_Reg}]
set_property offset 0 [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_bram_ctrl_0_Mem0}]
set_property offset 0 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_bram_ctrl_0_Mem0}]
set_property offset 0x2000 [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_gpio_0_Reg}]
set_property offset 0x2800 [get_bd_addr_segs {holy_wrapper_0/m_axi_lite/SEG_axi_uartlite_0_Reg}]
set_property offset 0x2800 [get_bd_addr_segs {holy_wrapper_0/m_axi/SEG_axi_uartlite_0_Reg}]
set_property offset 0x2000 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_gpio_0_Reg}]
set_property offset 0x2800 [get_bd_addr_segs {jtag_axi_0/Data/SEG_axi_uartlite_0_Reg}]

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


# Validate + wrapper
validate_bd_design
make_wrapper -files [get_files ./HOLY_SOC/holy_soc_project.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./HOLY_SOC/holy_soc_project.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

# generate synth, inmpl & bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 6