# Test GPIO
#
# This script loads a basic program in memory that write 0x00000001 to addr 0x00000000 from GPIO base addr.
# This turns on the last LED. This is useful to test the GPIO setup.
# To use it, make sure you have the "JTAG to AXI MASTER" in the SoC design;
# program the device in vivado; and source this file (make sure addresses are ok too). You can then release
# reset on the core.
#
# BRH 11/12

reset_hw_axi [get_hw_axis hw_axi_1]
set gpio_address 0x00002000
set wt axi_gpio_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $gpio_address -len 1 -data {00000001}
run_hw_axi [get_hw_axi_txns $wt]