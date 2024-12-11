# Infinite loop
#
# This script loads a basic program in memory that runs a NOP and branche back to this said NOP.
# It serves as a great test to check if your setup is right and you debug signals works before moving
# on to more elaborate testing. To use it, make sure you have the "JTAG to AXI MASTER" in the SoC design;
# program the device in vivado; and source this file. (make sure bram address is ok too). You can then release
# reset on the core.
#
# BRH 11/12

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt_inf
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 2 -data {
    00000013
    FE000EE3
}

run_hw_axi [get_hw_axi_txns $wt]