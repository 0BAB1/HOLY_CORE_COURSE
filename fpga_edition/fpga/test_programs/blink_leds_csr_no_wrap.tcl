# Blink leds
#
# This script loads a basic program in memory that blinks LEDs (using a register as a counter).
# To use it, make sure you have the "JTAG to AXI MASTER" in the SoC design;
# program the device in vivado; and source this file. (make sure addresses are ok too). You can then release
# reset on the core.
#
# Fun fact : that this was the very first program entirely written in ASM and then compiled !
#
# BRH 11/12

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 14 -data {
    00002337
    00000913
    0040006f
    00000313
    00002337
    00190913
    0040006f
    01232023
    7c00d073
    02fafab7
    080a8a93
    fffa8a93
    fe0a9ee3
    fd9ff06f
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 20
run_hw_axi [get_hw_axi_txns $rt]