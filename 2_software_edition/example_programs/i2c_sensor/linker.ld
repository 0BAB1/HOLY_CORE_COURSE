ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 2K
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

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}