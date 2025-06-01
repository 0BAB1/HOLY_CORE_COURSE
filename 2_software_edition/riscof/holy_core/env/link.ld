OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x8000
}

SECTIONS
{
  . = ORIGIN(RAM);

  .text.init : { *(.text.init) }
  . = ALIGN(0x4);

  .tohost : { *(.tohost) }
  . = ALIGN(0x4);

  .text : { *(.text) }
  . = ALIGN(0x4);

  .data : { *(.data) }
  .data.string : { *(.data.string)}

  .bss : { *(.bss) }

  _end = .;
}

