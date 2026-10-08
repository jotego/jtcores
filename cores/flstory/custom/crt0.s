    .module crt0
    .area _HEADER (ABS)
    .org 0x0000          ; Reset vector at 0x0000
    jp _start            ; Jump to main program

    .area _CODE
    .globl _main
_start:
    ld sp, #0xC800       ; Set stack pointer at top of RAM (grows downward)
    jp _main
