<!--
SOFTWARE EDITION TUTORIAL

AUTHOR :  BABIN-RIBY Hugo a.k.a. BRH

Plese refer to the LICENSE for legal details on this document

LAST EDIT : 05/25
-->

# SOFTAWRE EDITION

## The goal

Now that we can use our core on a basic SoC, things start to get interresting. We can write stuff and read sensors using assembly and it works great.

But something feels off : Productivity.

Yes I know, we are not here to revolutionize anything, but if we want to use the core on a larger project, pure assembly is quickly going to be annoying.

### We need C

The goal is simple here : **Make sofware developement easier**.

For this it's simple, we'll need to compile from C. from there we'll be able to define handy libraries and use other people's librairy instread of spending 2 whole day reding datasheets to get pressure reading from a sensor using an assembly hous of cards (speaking from experience, and yes this is the reason why I decided to start this edition).

At the end of this edition we'll be able to :

- Use basic C librairies and compile programs for the core.
- Handle `ecall` and **exceptions** (like when an illegal instruction is issued)
- Have a better boot loader to
  - Load programs from a live debugger
  - Or loads programs from an SD card on the SoC

As you can see there is a lot of works in all fields :

- Hardware
  - We need to finally implement traps and the environement instruction we always avoided until now
  - We need to better our testing solution to make sure our core is 100% compliant
  - Add CSRs and verify their behavior. *Good news :* we already have Zicsr from the *fpga edition* so that will win us some work.
- Software
  - We need to add a trap handler and basic bare metal utilities for ecalls (more on that later).
  - We need to develop bootloader solutions.
- SoC
  - We need to reorganize our SoC to be more versatile
  - Add an SD Card "data mover" and a way to communicate with a debugger
