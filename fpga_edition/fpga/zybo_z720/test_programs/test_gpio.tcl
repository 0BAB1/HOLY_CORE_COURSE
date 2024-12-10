# This test program should turn the led on

reset_hw_axi [get_hw_axis hw_axi_1]
set gpio_address 0x00002000
set wt axi_gpio_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $gpio_address -len 1 -data {00000001}
run_hw_axi [get_hw_axi_txns $wt]