MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 256M
}

ENTRY(_start)
SECTIONS {
    . = ALIGN(4);
    __stacktop = ORIGIN(RAM) + LENGTH(RAM);  /* Stack at end of RAM */
    .text :
    {
        . = ALIGN(4);
        *(.text.start)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _etext = .;
        _sidata = _etext;
    } > RAM
    .data : AT ( _sidata )
    {
        . = ALIGN(4);
        _sdata = ABSOLUTE(.);
        _ram_start = ABSOLUTE(.);
        . = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
        _edata = ABSOLUTE(.);
    } > RAM
    .bss :
    {
        . = ALIGN(4);
        _sbss = ABSOLUTE(.);
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = ABSOLUTE(.);
    } > RAM

    .heap :
    {
        . = ALIGN(8);
        _heap_start = ABSOLUTE(.);
    } > RAM
}
