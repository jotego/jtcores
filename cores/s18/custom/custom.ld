OUTPUT_ARCH(m68k)
OUTPUT(rom.bin)
MEMORY
{
	ROM  (rx) : ORIGIN = 0x000000, LENGTH = 128K
	RAM (rwx) : ORIGIN = 0xff0000, LENGTH = 32K
}

SECTIONS
{
	.vectors 0x00000000 : {
		KEEP(*(.vectors))
	} > ROM
	.text 0x000100 : AT (0x100) {
		*(.text)
		*(.rodata)
	} > ROM

	.data 0xff0000 : AT (0x100+SIZEOF(.text)) {
		_data_start = .;
		*(.data)
		_data_end = .;
	} > RAM

	.stack 0xff0000 : AT (SIZEOF(.text)) {
		_stack_start = .;
		*(.stack)
		_stack_end = .;
	} > RAM
}

PROVIDE(_end = .);