This edition will aim at adding basic imprvements for pareto optimal improvements.

The objective will be to get max FPS on DOOM.

## Pareto-Optimal Performance Upgrades for an RV32I Doom-Capable CPU

According to mr GPT:

| Upgrade | Performance Impact | Implementation Cost | Rationale |
|---------|---------------------|-----------------------|-----------|
| Small Instruction Cache or Prefetch Buffer | Very High | Low–Medium | Removes instruction-fetch stalls and greatly accelerates tight loops used in DOOM. |
| 2–3 Stage Pipeline | High | Medium | Allows significantly higher clock frequency (e.g., 25 MHz → 50–100 MHz) with limited hazard logic. |
| Hardware Multiply (M Extension or Iterative MUL) | Medium | Low–Medium | DOOM relies on fixed-point math; hardware MUL delivers substantial speedup. |
| Small Data Cache or Scratchpad RAM | Medium | Medium | Reduces bottlenecks in texture lookups and framebuffer writes; write buffer enhances throughput. |
| Simple Branch Prediction | Low–Medium | Low | Cuts pipeline flushes; static “backwards-taken” rule is easy and effective. |
| Wider or Burst-Capable Memory Interface | Medium–High | Medium–High | Improves instruction throughput and framebuffer access on slow external memory. |

## todo for this edition

- Add performance CSR to gather data on CPU performances
- Add basic improvements above.
- Add 1-2 advanced improvements to make something a bit more original