# Blink leds loader
#
# BRH 06/25

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 35 -data {
    00001117
    88c10113
    00002337
    000033b7
    fff3e393
    7c131073
    7c239073
    008000ef
    0000006f
    ff010113
    07c00513
    00112623
    020000ef
    0000006f
    00003737
    80872783
    0087f793
    fe079ce3
    80a70223
    00008067
    00054683
    02068263
    00003737
    00150513
    80872783
    0087f793
    fe079ce3
    80d70223
    00054683
    fe0694e3
    00008067
    6c6c6548
    77202c6f
    646c726f
    000d0a21
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 35
run_hw_axi [get_hw_axi_txns $rt]