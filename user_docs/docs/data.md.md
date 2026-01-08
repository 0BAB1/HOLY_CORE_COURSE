# Data Sheet

This docuent aims at giving quick references on misc data and acts as a quick "cheat sheet".

## RISC-V CSRs list

| Name | Address | Type | Reset Value | Bit Layout |
|------|---------|------|-------------|-----------|
| `mstatus` | 0x300 | RW | 0x00001800 | Bit 3: MIE (Machine Interrupt Enable) / Bit 7: MPIE (Previous MIE) |
| `misa` | 0x301 | RO | 0x40140100 | - |
| `mie` | 0x304 | RW | 0x00000000 | Bit 3: MSIE (Software Interrupt Enable) / Bit 7: MTIE (Timer Interrupt Enable) / Bit 11: MEIE (External Interrupt Enable) |
| `mtvec` | 0x305 | RW | 0x00000000 | Bits 31:2: Base address (DIRECT ADDR ONLY SUPPOTED) |
| `mscratch` | 0x340 | RW | 0x00000000 | Bits 31:0: Scratch data (general-purpose) |
| `mepc` | 0x341 | RW | 0x00000000 | Bits 31:0: Exception program counter address |
| `mcause` | 0x342 | RW | 0x00000000 | Bit 31: Interrupt flag / Bits 30:0: [Exception/Interrupt code](#mcause-values-and-mtval-contents) |
| `mtval` | 0x343 | RW | 0x00000000 | Bits 31:0: [Exception-specific value](#mcause-values-and-mtval-contents) (faulting address or instruction) |
| `mip` | 0x344 | RO | 0x00000000 | Bit 3: MSIP (Software Interrupt Pending) / Bit 7: MTIP (Timer Interrupt Pending) / Bit 11: MEIP (External Interrupt Pending) |

## Debug CSRs

| Name | Address | Type | Reset Value | Bit Layout |
|------|---------|------|-------------|-----------|
| `dcsr` | 0x7B0 | RW | 0x00000000 | Bit 2: Step (single-step enabled) / Bits 8:6: Cause (debug entry reason) / Bits 15: ebreakm |
| `dpc` | 0x7B1 | RW | 0x00000000 | Bits 31:0: Debug program counter (PC when entering debug mode) |
| `dscratch0` | 0x7B2 | RW | 0x00000000 | Bits 31:0: Debug scratch register (general-purpose) |
| `dscratch1` | 0x7B3 | RW | 0x00000000 | Bits 31:0: Debug scratch register (general-purpose) |


## Custom CSRs list

 Name | Address | Type | Reset Value | Function |
|------|---------|------|-------------|----------|
| `flush_cache` | 0x7C0 | WO | 0x00000000 | Cache flush command. Writing any value triggers cache flush; resets to 0 on next cycle. |
| `data_non_cachable_base` | 0x7C1 | RW | 0x00000000 | Data non-cacheable base address. Sets lower bound of non-cacheable memory region. |
| `data_non_cachable_limit` | 0x7C2 | RW | 0xFFFFFFFF | Data non-cacheable limit address. Sets upper bound of non-cacheable memory region. |
| `instr_non_cachable_base` | 0x7C3 | RW | 0x00000000 | Instruction non-cacheable base address. Sets lower bound of non-cacheable instruction region. |
| `instr_non_cachable_limit` | 0x7C4 | RW | 0xFFFFFFFF | Instruction non-cacheable limit address. Sets upper bound of non-cacheable instruction region. |

## `mcause` Values and `mtval` Contents

| mcause[31] | mcause[30:0] | Type | Exception/Interrupt | mtval Contains |
|-----------|------------|------|-------------------|---------------|
| 0 | 0 | Exception | Instruction address misaligned | Target address from second_adder (J/B target) |
| 0 | 2 | Exception | Illegal instruction | Current fetch instruction |
| 0 | 3 | Exception | Breakpoint (ebreak) | Current PC |
| 0 | 4 | Exception | Load address misaligned | Target address from ALU (load address) |
| 0 | 6 | Exception | Store address misaligned | Target address from ALU (store address) |
| 0 | 11 | Exception | Environment call from M-mode (ecall) | 0 |
| 1 | 3 | Interrupt | Machine software interrupt (MSIP) | — |
| 1 | 7 | Interrupt | Machine timer interrupt (MTIP) | — |
| 1 | 11 | Interrupt | Machine external interrupt (MEIP) | — |