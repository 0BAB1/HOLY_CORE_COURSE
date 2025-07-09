# HOLY CLINT

A simple (holy) Core Local INTerrupt controller.

You can communicate with it using AXI-LITE.

Meant for a single core 32 bits RISC-V SoC.

Exit complicated "industry grade" CLINTs, this one is simple and straight forward. As it should be.

## Registers & Memory Map

| Address Offset | Register                  | Description                                                                            |
| -------------- | ------------------------- | -------------------------------------------------------------------------------------- |
| `0x0000`       | `msip`  | Sofware interrupt, only the LSB will trigger the output interrupt request. Others will be ignored.|
| `0x4000`       | `mtimecmp[31:0]`  | Low word for the 64 bits `mtimecmp` |
| `0x4004`       | `mtimecmp[63:32]`  | High word for the 64 bits `mtimecmp` |
| `0xBFF8`       | `mtime[31:0]`  | High word for the 64 bits `mtime` |
| `0xBFFC`       | `mtime[63:32]`  | High word for the 64 bits `mtime` |

## Features

Well.. its a basic CLINT... Asserts `timer_irq` when `mtime >= mtimecmp` and asserts `soft_itr` as long as the LSB in 1.

Note that `mtime` is read only.

What esle ? Oh yeah, if the naming is "not standard" and you would like me to name my signals in a "better way" then womp womp, go touch some grass and come back later.