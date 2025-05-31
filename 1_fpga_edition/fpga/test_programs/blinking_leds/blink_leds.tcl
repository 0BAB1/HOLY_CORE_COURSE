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
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 20 -data {
    00000337
    000023b7
    fff3e393
    7c131073
    7c239073
    00003537
    80050513
    04800593
    00d00613
    00058683
    00852703
    00477713
    fe070ce3
    00d50223
    00158593
    fff60613
    fe0612e3
    0000006f
    6c6c6548
    57202c6f
    646c726f
    0000000a
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 20
run_hw_axi [get_hw_axi_txns $rt]