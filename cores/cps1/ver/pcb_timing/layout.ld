SECTIONS { . = 0; .vectors : { KEEP(*(.vectors)) } . = 0x400; .text : { *(.text*) *(.rodata*) } .data : { *(.data*) } .buildmeta : { KEEP(*(.buildmeta)) } }
