#!/bin/bash -e

main(){
	VRAM_OFFSET=$((0x200000))
	SIZE=$((0x10000)) # 64 KiB
	REST="rest.bin"

	refresh_sdram
	get_main
	substitute_64k_in_sdram
	get_vdp
	obtain_mmr_hex
}

refresh_sdram(){
	jtutil sdram
}

substitute_64k_in_sdram(){
	dd if=$REST of=sdram_bank0.bin bs=1 count=$SIZE seek=$VRAM_OFFSET conv=notrunc
}

get_vdp(){
	dd if=$REST of=vdp.bin bs=1 count=$SIZE skip=$SIZE conv=notrunc
}

get_main(){
	tail --bytes 18 $REST > main.bin
}

obtain_mmr_hex(){
	tail --bytes 512 cscn.bin | hexdump -v -e '/2 "%04X\n"' > mmr.hex
}

main $*
