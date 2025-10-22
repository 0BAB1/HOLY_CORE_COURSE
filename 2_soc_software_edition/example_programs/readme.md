# Holy Core Example Programs

In this folder, you can experiment with pre-written exmaple programs.

## Usage

To build a program:

```sh
make APP=<app_name>
```

> Note: if you don't specify an app name, it will default to hello world.

To clean all the built binaries and others:

```sh
make clean
```

## Running the exmaple programs on the HOLY CORE

### On FPGA

To run the programs on FPGA, it depends on the state of the ROM and the SoC.

For exmaple, if your bootrom (defined in `root/fpga/ROM` from the rom.S program) jumps to 0x8000000 directly, you simply need to load you program in the RAM @ 0x80000000 and it wil get executed almost intantly upon reset release.

At the time of writing this, the bootrom implements a simple infinite loops that blink a GPIO LED.

If like me, you have an inifite loop bootrom (which role is simply to start the CORE in a stable parked state upon reset release), the CPU gets in a state where it just sits there a wait for something to happens.

The "something" is you sending a debug request using openOCD:

```sh
openocd -f <root>/fpga/arty_S7/holy_core_openocd.cfg 
```

You'll need some kind of transport module (I use the HS2 revA). that will serve as a bridge (using an FTDI chip) between the USB and the SoC's JTAG debug module, which in turn translate the standard JTAG debug commands into debug resuests and memory manipulations to offer you a nice debug experience.

> Depending on your fpga and debug dingle, you'll need to adapt. You can open an issue in the ithub if you have trouble making it work.

Once openOCD recognizes the HOLY CORE's debug module, open GDB:

```sh
riscv64-unknown-elf-gdb <path to the built elf> 
```

then in gdb

```sh
(gdb) target remote :3333
(gdb) load
(gdb) c
```

> target remote tells GDB to use the loacal :3333 server as an interface, which is openocd, and it will translate GDB commands into standard JTAG instruction for the harware to understand

> load loads the program in memory, the SoC's debug module being a SoC master, it diretly write you binary in the RAM, just like the HOLY CORE would

> c simple tells GDB to "continue" it will execute you program

### In simulation

The FPGA top modules can be simuated in the root/fpga/ folder by running:

`make`

Using a classic cocotb workflow, excpet this tb has no assertions and simply runs the program in the ROM (before running some basic I/O test eg debug request or interruts requests.)

You can use the fpga/ROM folder to paste your hexdump in the ROM, effectively running your program in a simulated environement, just like usual

> WARNING : do not use the riscof's or the `tb/holy_core/` testbenches as these run a fair amount of assertion which will mess everything up, on top of that, the fpga/ testbench run on the actual fpga's top module (execpt highe level I/Os are not there but you have some AXI slaves to act like it.)