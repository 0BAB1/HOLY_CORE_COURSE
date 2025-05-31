# Test BRAM
#
# This script loads a basic program in memory that write 0xDEADBEEF to addr 0x00000000 in BRAM.bram_address
# It then reads the data. This is useful to test the BRAM setup.
# To use it, make sure you have the "JTAG to AXI MASTER" in the SoC design;
# program the device in vivado; and source this file (make sure addresses are ok too). You can then release
# reset on the core.
#
# BRH 11/12

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 1 -data {DEADBEEF}
run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 1
run_hw_axi [get_hw_axi_txns $rt]