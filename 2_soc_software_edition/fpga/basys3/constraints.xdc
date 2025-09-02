# CONSTRAINT FILE FOR TARGET BOARD : BASYS3 ONLY

set_property PACKAGE_PIN V16 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]

set_property PACKAGE_PIN V17 [get_ports axi_reset]
set_property IOSTANDARD LVCMOS33 [get_ports axi_reset]

# UART Constraints

# RX input from host (USB-UART TX → FPGA RX)
set_property PACKAGE_PIN B18 [get_ports uart_rtl_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_rxd]

# TX output to host (FPGA TX → USB-UART RX)
set_property PACKAGE_PIN A18 [get_ports uart_rtl_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_txd]

# I2C BUS constraints (connected to dedicated SDA and SCL digital IO shield)

# set_property PACKAGE_PIN J13 [get_ports iic_rtl_sda_io]
# set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_sda_io]
# set_property PACKAGE_PIN J14 [get_ports iic_rtl_scl_io]
# set_property IOSTANDARD LVCMOS33 [get_ports iic_rtl_scl_io]