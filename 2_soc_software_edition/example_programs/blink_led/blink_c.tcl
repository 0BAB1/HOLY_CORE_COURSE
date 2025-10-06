# Blink leds loader
#
# BRH 06/25

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 38 -data {
    00001117
    89810113
    00002337
    000033b7
    fff3e393
    7c131073
    7c239073
    03c000ef
    0000006f
    ff010113
    00a12623
    00c12783
    fff78713
    00e12623
    00078c63
    00000013
    00c12783
    fff78713
    00e12623
    fe0798e3
    01010113
    00008067
    10600637
    00100593
    0007a6b7
    00b60023
    11f68793
    00000013
    00078713
    fff78793
    fe071ae3
    00060023
    11f68793
    00000013
    00078713
    fff78793
    fe071ae3
    fd1ff06f
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 38
run_hw_axi [get_hw_axi_txns $rt]