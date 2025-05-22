#!/bin/bash -e

main(){
	VRAM_OFFSET=$((0x200000))
	SIZE=$((0x10000)) # 64 KiB
	BYTES=$((2+16+32)) # main + video + vdp
	REST="rest.bin"
	SKIP=0

	refresh_sdram
	get_regs
	substitute_64k_in_sdram
	get_vdp
	get_vdp_mem
	obtain_mmr_hex
}

refresh_sdram(){
	jtutil sdram
}

substitute_64k_in_sdram(){
	dd if=$REST of=sdram_bank0.bin bs=1 count=$SIZE seek=$VRAM_OFFSET conv=notrunc
	SKIP=$((SKIP+SIZE))
}

get_vdp(){
	dd if=$REST of=vdp.bin bs=1 count=$SIZE skip=$SKIP conv=notrunc
	SKIP=$((SKIP+SIZE))
}

get_vdp_mem(){
	dd if=$REST of=vdp_col.bin bs=1 count=128 skip=$SKIP conv=notrunc
	jtutil drop1    < vdp_col.bin > vdp_col_hi.bin
	jtutil drop1 -l < vdp_col.bin > vdp_col_lo.bin
}

get_regs(){
	tail --bytes $BYTES $REST > regs.bin
}

obtain_mmr_hex(){
	tail --bytes 512 cscn.bin | hexdump -v -e '/2 "%04X\n"' > mmr.hex
}

main $*
