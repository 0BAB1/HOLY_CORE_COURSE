# TCL Test program loader for JTAG to AXI master

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 16 -data {
    00002337
    00000993
    00100913
    07F00A13
    01232023
    00430313
    00198993
    FF499AE3
    00002903
    00000013
    FE000EE3
    00000013
    00000013
    00000013
    00000013
    00000013
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 16
run_hw_axi [get_hw_axi_txns $rt]