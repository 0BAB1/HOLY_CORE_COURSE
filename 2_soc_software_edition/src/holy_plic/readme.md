# Maybe the simplest, holiest PLIC you'll see

Complies with the [Privileged Specs](https://people.eecs.berkeley.edu/~krste/papers/riscv-privileged-v1.9.pdf#page=73). But not fully. Who cares ?

Meant to be used for a single core SoC.

Want more cores ? Womp Womp. Then that means who work in the industry, which means it your job to do it.

Exit the unreadable codebases. This PLIC goes straight to the point:

- 5 external interrupts lines by default
  - can add more or less. Who cares ? its **SIMPLE** & **TRANSPARENT** !
  - Priorities ? `itr5` has priority over `itr4`. And so on... Thats it.
  - IDs range from 1 to 5 (0 -> no interrupt if polling)
- 1 `ext_itr` ouput, that goes to the core.
- An `AXI_LITE` interface, standard, widely used. As it should be.

## Memory Map

| Address Offset | Register                  | Description                                                                            |
| -------------- | ------------------------- | -------------------------------------------------------------------------------------- |
| `0x0000`       | `ENABLE`                  | Bitmask: enables/disables each interrupt source. Bits `[4:0]`.                         |
| `0x0004`       | `CONTEXT_CLAIM_COMPLETE`  | Read: claim highest priority pending IRQ. Write: complete IRQ by writing same ID back. |

> Yes, there is no interrupt threshold (**bloat !**). If you wanna stop using an interrupt then just unplug it or use the `ENABLE` mask. If you want to add such a feature, **contributions are welcome.**