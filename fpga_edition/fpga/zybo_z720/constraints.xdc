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
