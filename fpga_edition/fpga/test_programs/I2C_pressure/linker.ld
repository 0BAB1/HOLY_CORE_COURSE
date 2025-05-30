MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x2000
}

SECTIONS {
    .text : {
        *(.text*)
    } > RAM
    .data : {
        *(.data*)
    } > RAM
    .bss : {
        *(.bss*)
    } > RAM
}
