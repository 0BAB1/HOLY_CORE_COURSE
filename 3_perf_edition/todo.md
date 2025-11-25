# TODO

remove / cleanup debug probe (datapath and fpga top wapper)
Improve instr cache system
  - remove write
  - reduced drastically burst size to 16 (I$ will always be FFs)
  - Test it on riscof
  - test in on DOOM
  - test in in sim
  - Do it again with 8 and 32, see which is best ...
Pipeline the core
Add M extension support

# DOING

Improve data cache system
  - 2 ways 8 sets data
  - Test it on riscof
  - test in on DOOM
  - test in in sim
  - Implement 1 cycle hand shake to make it in BRAM

# DONE

