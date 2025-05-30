# Hello world loader
#
# BRH 05/25

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 118 -data {
    00002337
    000033b7
    fff3e393
    7c131073
    7c239073
    00003537
    00a00713
    04e52023
    00300713
    10e52023
    00100713
    10e52023
    10452703
    03477713
    fe071ce3
    1ee00713
    0f500793
    20000813
    10e52423
    10f52423
    11052423
    10452703
    03477713
    fe071ce3
    1ee00713
    0f400793
    20900813
    10e52423
    10f52423
    11052423
    10452703
    03477713
    fe071ce3
    1ee00713
    2f300793
    10e52423
    10f52423
    000012b7
    9c428293
    fff28293
    fe029ee3
    10452703
    03477713
    fe071ce3
    1ef00713
    20100793
    10e52423
    10f52423
    10452703
    04077713
    fe071ce3
    10c50803
    00887813
    fa0812e3
    000012b7
    9c428293
    fff28293
    fe029ee3
    10452703
    03477713
    fe071ce3
    1ee00713
    2f800793
    10e52423
    10f52423
    000012b7
    9c428293
    fff28293
    fe029ee3
    10452703
    03477713
    fe071ce3
    1ef00713
    20100793
    10e52423
    10f52423
    000012b7
    9c428293
    fff28293
    fe029ee3
    10452703
    04077713
    fe071ce3
    10c50803
    000038b7
    80088893
    00485713
    00f77713
    03000793
    00f70733
    03a00313
    00674463
    00770713
    0088a283
    0082f293
    fe029ce3
    00e88223
    00f87713
    03000793
    00f70733
    03a00313
    00674463
    00770713
    0088a283
    0082f293
    fe029ce3
    00e88223
    00a00713
    0088a283
    0082f293
    fe029ce3
    00e88223
    00d00713
    0088a283
    0082f293
    fe029ce3
    00e88223
    0000006f
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 118
run_hw_axi [get_hw_axi_txns $rt]