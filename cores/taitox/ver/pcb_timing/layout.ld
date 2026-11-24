OUTPUT_ARCH(m68k)
ENTRY(start)
SECTIONS
{
    . = 0;
    .vectors : { KEEP(*(.vectors)) }
    . = 0x100;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
