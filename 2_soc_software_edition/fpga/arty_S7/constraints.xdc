# CONSTRAINT FILE FOR TARGET BOARD : ARTY S7-50 ONLY

# SW3
set_property PACKAGE_PIN G18 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]

# SW2     
set_property PACKAGE_PIN H18 [get_ports axi_reset]
set_property IOSTANDARD LVCMOS33 [get_ports axi_reset]

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

#set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets \
#  design_1_i/top_0/inst/wrapped/debug_mem_conv/i_axi_to_mem/i_axi_to_detailed_mem/i_mem_to_banks/gen_resp_regs[0].i_ft_reg/fifo_i/gen_buf.cnt_q_reg[1] ]

set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets {design_1_i/top_0/inst/wrapped/core/gen_data_no_cache.data_no_cache/d_cache_stall}]

set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets design_1_i/top_0/inst/wrapped/core/gen_data_no_cache.data_no_cache/d_cache_stall_INST_0_i_1_n_0]

set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets design_1_i/top_0/inst/wrapped/core/gen_data_no_cache.data_no_cache/stall]
