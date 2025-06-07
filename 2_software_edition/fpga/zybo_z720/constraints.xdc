# CONSTRAINT FILE FOR TARGET BOARD : ZYBO Z7-20 ONLY

set_property PACKAGE_PIN T16 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]

set_property PACKAGE_PIN W13 [get_ports axi_reset]
set_property IOSTANDARD LVCMOS33 [get_ports axi_reset]

# UART Constraints

# JE1 = RX input from host (USB-UART TX → FPGA RX)
set_property PACKAGE_PIN U7 [get_ports uart_rtl_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_rxd]

# JE2 = TX output to host (FPGA TX → USB-UART RX)
set_property PACKAGE_PIN W8 [get_ports uart_rtl_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_txd]

###
# I2C BUS constraints, uncomment to use IIC exmaple sofawre
# after adding IIC AXI Ip in the SoC
###

I2C BUS constraints
set_property PACKAGE_PIN T11 [get_ports iic_rtl_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_sda_io]
set_property PACKAGE_PIN T10 [get_ports iic_rtl_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_scl_io]

# I2C BUS debug
# set_property PACKAGE_PIN P14 [get_ports debug_sda]
# set_property IOSTANDARD LVCMOS33 [get_ports debug_sda]
# set_property PACKAGE_PIN R14 [get_ports debug_scl]
# set_property IOSTANDARD LVCMOS33 [get_ports debug_scl]
# set_property PACKAGE_PIN V16 [get_ports debug_led]
# set_property IOSTANDARD LVCMOS33 [get_ports debug_led]