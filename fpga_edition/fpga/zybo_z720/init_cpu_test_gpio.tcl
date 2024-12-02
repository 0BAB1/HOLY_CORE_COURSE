# This programs loads a basic program in memory :
# lui x6 0x2
# addi x18 x0 0x1
# sw x18 0x0(x6)
# lw x18 0x0(x0) ; simply to create a cache miss and write back

# This test program should write DEADBEEF to bram and then read it

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000
set wt axi_bram_wt
create_hw_axi_txn $wt [get_hw_axis hw_axi_1] -type write -address $bram_address -len 4 -data {
    00002337
    00100913
    01232023
    00002903
}

run_hw_axi [get_hw_axi_txns $wt]

set rt axi_bram_rt
create_hw_axi_txn $rt [get_hw_axis hw_axi_1] -type read -address $bram_address -len 4
run_hw_axi [get_hw_axi_txns $rt]