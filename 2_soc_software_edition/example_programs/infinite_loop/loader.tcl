# Blink leds loader
#
# BRH Auto-Generated

reset_hw_axi [get_hw_axis hw_axi_1]
set bram_address 0x00000000

# Clear previous write transactions if any
if {[llength [get_hw_axi_txns]]} {
    delete_hw_axi_txns [get_hw_axi_txns]
}

create_hw_axi_txn axi_bram_wt_0 [get_hw_axis hw_axi_1] -type write -address 0x00000000 -len 1 -data {
    0000006F
}

run_hw_axi [get_hw_axi_txns axi_bram_wt_0]
