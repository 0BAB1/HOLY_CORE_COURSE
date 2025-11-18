# Doom classic port to my RISC-V emulator

This project is a port of the DOOM engine to [my RISC-V emulator](https://git.knazarov.com/knazarov/rve/).
It is based on the [doom_riscv](https://github.com/smunaut/doom_riscv) by Sylvain Munaut. I had to change
some of the implementation details like interactions with the framebuffer, timer and uart, as well as fix
a few bugs.

## Compiling

You'd need [nix package manager](https://nixos.org/) in order to build the project. This is because installing correct cross-toolchain is difficult, and I don't know of other ways except nix that make it easy.

If you don't have it, install it like this:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Then all you have to do is to run:

```
nix build
```

And you'll get `result/bin/doom-riscv.elf` which you can run with the emulator as follows:

```
rve result/bin/doom-riscv.elf
```
