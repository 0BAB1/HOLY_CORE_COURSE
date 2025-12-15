# TODO

Make a specialize ReadOnly no cache for instructions (save couple hundred LUTs)

In datapath, harmonize notation (especially across caches signals)

Add litex support for better SoC flexibility and portability.
  - or manually add board supports + start supporting other vendors (latice, altera, gowin...) but that's a big budget tbh.

# DOING

Add M extension support

Remove / cleanup debug probe (datapath and fpga top wapper)

# DONE

make part 3 CI actually test everything

Improve and specialize I$ cache system
  - Remove write
  - Reduce burst size (miss cost)
  - Add a way (WAY better perfs in dual loops)
  - test it on doom
  - Find optimal point for resources / perfs

Get rid of comb loops warnings
- I modified CSR file (stall became instruction valid) => test if traps still work as prblem rose in riscof

Synt d$ as BRAM (done, allowed for an easy fit of 1kB cache, could do more by nuking next_ signals for tags and flags (way less LUTs) => nex TODO)
Use TFT 2.8" screen for DOOM
Add QSPI and SPI drivers to SoC (thanks claude LOL)
2 ways 8 sets data (did 2 ways, 4 sets, 8 words per set at first bc no BRAM yet and won't fit otherwaise)
test new data cache in on DOOM (POC) -> GOT 1 FPS in game !
test in in sim
