# This programs loads a basic program in memory that runs a NOP and branche back to this said NOP

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt_inf
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 2 -data {
    00000013
    FE000EE3
}

run_hw_axi [get_hw_axi_txns $wt]