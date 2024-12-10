# TCL Test program loader for JTAG to AXI master

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 20 -data {
    00002337
    00000993
    08000a13
    00000913
    0040006f
    00000313
    00002337
    00000993
    00190913
    0040006f
    01232023
    00430313
    00198993
    ff499ae3
    00002b83
    02fafab7
    080a8a93
    fffa8a93
    fe0a9ee3
    fc9ff06f
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 16
run_hw_axi [get_hw_axi_txns $rt]