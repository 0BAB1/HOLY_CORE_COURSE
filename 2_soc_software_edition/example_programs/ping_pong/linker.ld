ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        _text_start = .;
        *(.text*)
        _text_end = .;
    } > RAM
    
    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > RAM

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
    } > RAM

    /* STACK AT TOP OF RAM */
    .stack (NOLOAD) : ALIGN(16) {
        _stack_top = ORIGIN(RAM) + LENGTH(RAM);
        _stack_bottom = _stack_top - 0x2000; /* 8KB stack */
    } > RAM
}