ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        *(.text*)
    } > RAM

    .data : {
        *(.data*)
    } > RAM

    .bss : {
        *(.bss*)
        *(COMMON)
    } > RAM

    .stack (NOLOAD) : {
        _stack_top = ORIGIN(RAM) + LENGTH(RAM);
        _stack_bottom = _stack_top - 0x800; /* 2KB stack */
        . = _stack_top;
    } > RAM
}
