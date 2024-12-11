# This test program should write DEADBEEF to bram and then read it

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 1 -data {DEADBEEF}
run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 1
run_hw_axi [get_hw_axi_txns $rt]