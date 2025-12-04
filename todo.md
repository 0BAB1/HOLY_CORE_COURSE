# TODO

Remove / cleanup debug probe (datapath and fpga top wapper)

Pipeline the core (OBJ = 100MHz)
  - Get rid of comb loops warnings

Add M extension support


# DOING

Improve and specialize I$ cache system
  - Remove write
  - Reduce burst size (miss cost)
  - Add a way (WAY better perfs in dual loops)
  - test it on doom
  - Find optimal point for resources / perfs

Improve data cache system
  - Synth as BRAM
  - Find optimal point for resources / perfs

# DONE

Use TFT 2.8" screen for DOOM
Add QSPI and SPI drivers to SoC (thanks claude LOL)
2 ways 8 sets data (did 2 ways, 4 sets, 8 words per set at first bc no BRAM yet and won't fit otherwaise)
test new data cache in on DOOM (POC) -> GOT 1 FPS in game !
test in in sim
