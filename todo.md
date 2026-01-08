# TODO

Make a specialize ReadOnly no cache for instructions (save couple hundred LUTs)


Add litex support for better SoC flexibility and portability.
  - or manually add board supports + start supporting other vendors (latice, altera, gowin...) but that's a big budget tbh.

Get rid of unecessry second adder logic, i.e. make this whole thing more readable and intuitive.

check and rework vivado tcl setup

add a cache invalider that simply set all valid bits to 0 in D$ (maybe I$ as well ? in theory useful but in practice completely useless)
  - this would allow to deactivate cache and then reactivate it + set all data as stale as it (the data) changed while deactivated redering cached data non valid.

in fpga for debugging : sepate a SIM ROM from actual ROM.

Start writing perf edition

Datapath major work for perf edition : Pipeline the CORE
- In datapath, harmonize notation (especially across caches signals)
- Rename LS decoder input to 2 bits wide offset instead of full blown alu restult

single step bug: executes ebreak instead of instructio when single stepping. That's because the debuggger effectlively replaces the breapoint with a ebreak and then restores it BUT the eabreak is in I$. solving this should be easy and involves either cache invalidation on flag everything as non cachbable when any form of debugging interaction is involved (but ebrak would still be in Icache...)

# DOING


# DONE

Add M extension support
  - update readme
  - update doc
  - make new course edition perf_edition.md

Remove / cleanup debug probe (datapath and fpga top wapper)

Make part 3 CI actually test everything

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
