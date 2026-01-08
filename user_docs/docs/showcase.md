# Showcase

You might be wondering what the **HOLY CORE** can actually do.

This section showcases a few projects built on top of the HOLY CORE to give a concrete idea of its capabilities and maturity.

!!! Tip "Add your project"
    You can contribute to [these docs](https://github.com/0BAB1/HOLY_CORE_COURSE/tree/master/user_docs/docs) and add your own project here!

## DOOM

The HOLY CORE runs **DOOM**.

![doom gameplay](./images/doom.gif)

Running DOOM was far from trivial, but it proved extremely valuable. It exposed several design flaws early on and ultimately demonstrated that the overall architecture is reasonably reliable (with caches enabled).

Performance-wise, there is still room for improvement. The main bottleneck is SPI data transfer, which currently limits the achievable FPS. This could be addressed by increasing the system frequency so both the core and SPI IP run faster, or by adding offloading logic such as a DMA-like mechanism.

More ambitious improvements would include pipelining the core and adding a scoreboard to allow multiple instructions to be in flight at once (for example, issuing an ALU operation while a load is still completing). For the purpose of a demo, however, the current implementation felt “good enough”, and I chose to move on to other projects.

!!! Note
    You can check out the code [here](https://github.com/0BAB1/HOLY_CORE_DOOM).

## UART Interrupt-Based Shell

A simple UART-based shell available in `example_programs/`.

All interactions are interrupt-driven, while the main program itself is just an infinite loop.

![shell screenshot](./images/holy_shell.png)

This was the first project heavily relying on interrupts, and it involved many moving parts. Implementing a basic core is one thing; correctly handling interrupts and exceptions is a completely different challenge—and, in my opinion, significantly harder than implementing RV32I itself.

You need to understand the relevant standards, implement CSRs (which essentially means supporting the Zicsr extension), carefully follow the specification for every corner case, and then somehow verify that everything behaves as expected.

On top of that, interrupts do not manage themselves. You need interrupt controller cores, and since there is no simple plug-and-play solution, you will most likely end up implementing your own CLINT and PLIC.

Getting this project to work was especially satisfying, as it represents the result of extensive specification research, design work, and verification, not even counting FPGA integration.

## Interrupt-Based Pong Game

Another interrupt-driven project, this time with a more dynamic workload: a simple **PONG** game.

![pong gameplay](./images/pong.gif)

Interrupts are used to update global variables, which are then consumed by the main loop to update the game state. The current state of the game is displayed over UART.

Using interrupts allows for a much cleaner game logic and demonstrates that interrupts work reliably beyond the simpler shell scenario. It also shows that the HOLY CORE can handle a quasi “real-time” environment, where a task is constantly running and interrupts are only used to update small pieces of state to avoid excessive CPU usage.

(The flickering cursor is just a UART artifact—nothing more.)

This project was the natural next step after the UART shell and further validates the interrupt subsystem in a more realistic use case.
