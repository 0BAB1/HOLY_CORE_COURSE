# CONSTRAINT FILE FOR TARGET BOARD : ARTY S7-50 ONLY

set_property PACKAGE_PIN M5 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS18 [get_ports cpu_reset]

set_property PACKAGE_PIN G18 [get_ports axi_reset]
set_property IOSTANDARD LVCMOS33 [get_ports axi_reset]

# UART Constraints

# JE1 = RX input from host (USB-UART TX → FPGA RX)
set_property PACKAGE_PIN V12 [get_ports uart_rtl_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_rxd]

# JE2 = TX output to host (FPGA TX → USB-UART RX)
set_property PACKAGE_PIN R12 [get_ports uart_rtl_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_txd]

# I2C BUS constraints (connected to dedicated SDA and SCL digital IO shield)

set_property PACKAGE_PIN J13 [get_ports iic_rtl_sda_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_sda_io]
set_property PACKAGE_PIN J14 [get_ports iic_rtl_scl_io]
set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_scl_io]