ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 256M
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
}

/* Define stack symbols outside of sections */
_stack_top    = ORIGIN(RAM) + LENGTH(RAM);
_stack_bottom = _stack_top - 0x40000; /* 256 KB */