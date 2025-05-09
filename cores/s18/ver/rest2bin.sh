#!/bin/bash -e

main(){
	VRAM_OFFSET=$((0x200000))

	refresh_sdram
	substitute_64k_in_sdram
	obtain_mmr_hex
}

refresh_sdram(){
	jtutil sdram
}

substitute_64k_in_sdram(){
	dd if=rest.bin of=sdram_bank0.bin bs=1 seek=$VRAM_OFFSET conv=notrunc
}

obtain_mmr_hex(){
	tail --bytes 512 cscn.bin | hexdump -v -e '/2 "%04X\n"' > mmr.hex
}

main $*
