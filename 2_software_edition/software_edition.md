<!--
SOFTWARE EDITION TUTORIAL

AUTHOR :  BABIN-RIBY Hugo a.k.a. BRH

Plese refer to the LICENSE for legal details on this document

LAST EDIT : 05/25
-->

# SOFTAWRE EDITION

## 0: The goal

Now that we can use our core on a basic SoC, things start to get interesting. We can write stuff and read sensors using assembly and it works great.

But something feels off : Productivity.

Yes I know, we are not here to revolutionize anything, but if we want to use the core on a larger project, pure assembly is quickly going to be annoying.

The goal is simple here : **Make software developement easier**.

For this, it's simple: we'll need to compile from C. From there we'll be able to define handy libraries and use other people's library instread of spending 2 whole day reading datasheets to get pressure reading from a sensor using an assembly house of cards (speaking from experience, and yes this is the reason why I decided to start this edition).

> And even if bare metal librairies are not common for sensors (they all are made for arduino), we'll at least be able to adapt them, thus saving some time to implement sensor interactions.

Here's what we want to to do in this edition to make the dev's life easier :

- Use basic C librairies and compile programs for the core.
- Have a better boot loader to
  - Load programs from a live debugger
  - Or loads programs from an SD card on the SoC

As you can see there is a lot of works in all fields :

- Hardware
  - We need to better our testing solution to make sure our core is 100% compliant (at least for MCU applications).
- Software
  - We need to add a trap handler and basic bare metal utilities for ecalls (more on that later).
  - We need to develop bootloader solutions.
- SoC
  - We need to reorganize our SoC to be more versatile
  - Add an SD Card "data mover" and a way to communicate with a debugger

## 0: Ensuring compliance

Before writing **ANY PIECE OF SOFWARE**, we need to make sur eveything we did until now is compliant with the RISC-V specs. This is because standard librairies we'll use down the road to lots of things and they don't care about our specific problems and hacks we made on the core's design back in the *previous editions*. We, as the designers, knew how to work around them when writing bare metal assembly. But standard pieces of code won't care.

So we'll use the [Riscof framework](https://riscof.readthedocs.io/en/latest/intro.html) to check our compliance.

To be honest, understading riscof is just so boring and such a pain as the docs are, like many low level projects docs, so weirdly put together. Like they always spend 10 lines explaining useles stuff and go over the core principles so fast. They always stay vague and use complicated words only to start digging in the details with a bad example.

> Yes I am fustrated and the are free and open source... But still ! It's always the same ! you spend 99% of the time yawning at their docs or trying ti unravel the meaning of what you're reading. It's crazy !

I'll let you go through the [quickstart guide to install everything you need](https://riscof.readthedocs.io/en/latest/installation.html).

Anyway, here is the big picture :

- Riscof is a set of assembly tests
- You use Riscof to run these tests on **2 targets:**
  - A sail golden reference (yet another language, meant to describe ISAs like RISC-V)
  - And of course... The *HOLY CORE* or whatever core you want to test.
- The goal : The results of the programs on the *HOLY CORE* have to be the same as the one from the **SAIL golen reference**.

> So Yeah, Riscof basically provides the assembly tests and then serves as a "comparing" tool.

## 1: Hello world

For starter, this *SOFTWARE EDITION* aims at having a better work environment to implement MCU software. The goal is not to make the core "Linux Capable".

