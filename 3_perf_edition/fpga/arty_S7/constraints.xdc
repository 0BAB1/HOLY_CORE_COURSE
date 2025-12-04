# CONSTRAINT FILE FOR TARGET BOARD : ARTY S7-50 ONLY

# SW3
set_property PACKAGE_PIN G18 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]

# SW2
#set_property PACKAGE_PIN H18 [get_ports axi_reset]
#set_property IOSTANDARD LVCMOS33 [get_ports axi_reset]

# UART Constraints

# JE1 = RX input from host (USB-UART TX → FPGA RX)
set_property PACKAGE_PIN V12 [get_ports uart_rtl_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_rxd]

# JE2 = TX output to host (FPGA TX → USB-UART RX)
set_property PACKAGE_PIN R12 [get_ports uart_rtl_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_txd]

# I2C BUS constraints (connected to dedicated SDA and SCL digital IO shield)

# set_property PACKAGE_PIN J13 [get_ports iic_rtl_sda_io]
# set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_sda_io]
# set_property PACKAGE_PIN J14 [get_ports iic_rtl_scl_io]
# set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_scl_io]

# JTAG tap constraints

set_property PACKAGE_PIN V15 [get_ports tms_i_0]
set_property IOSTANDARD LVCMOS33 [get_ports tms_i_0]

set_property PACKAGE_PIN U12 [get_ports td_i_0]
set_property IOSTANDARD LVCMOS33 [get_ports td_i_0]

set_property PACKAGE_PIN V13 [get_ports td_o_0]
set_property IOSTANDARD LVCMOS33 [get_ports td_o_0]

set_property PACKAGE_PIN T12 [get_ports tck_i_0]
set_property IOSTANDARD LVCMOS33 [get_ports tck_i_0]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_i_0_IBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_i_0]

# we allow this loops (involving stall) as the control signals aare logically mutually exclusive
# it should go away when pipelining / introducing better handshakes.
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets design_1_i/top_0/inst/wrapped/core/holy_csr_file/d_cache_stall]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets design_1_i/top_0/inst/wrapped/core/gen_data_cache.data_no_cache/d_cache_stall]
set_property ALLOW_COMBINATORIAL_LOOPS true [get_nets design_1_i/top_0/inst/wrapped/core/gen_data_cache.data_no_cache/stall]


# battle against stupid vivado optimsations:
set_property KEEP_HIERARCHY TRUE [get_cells -hierarchical *arbitre*]
set_property KEEP_HIERARCHY TRUE [get_cells -hierarchical *instr_cache*]
set_property KEEP_HIERARCHY TRUE [get_cells -hierarchical *data_cache*]
set_property DONT_TOUCH true [get_cells -hierarchical *instr_cache*]
set_property DONT_TOUCH true [get_cells -hierarchical *axi_instr*]
set_property DONT_TOUCH true [get_cells -hierarchical *arbitre*]
set_property DONT_TOUCH true [get_nets m_axi_*]
set_property KEEP_HIERARCHY yes [get_cells wrapped]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property RAM_STYLE BLOCK [get_cells -hierarchical *cache_data_way*]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
