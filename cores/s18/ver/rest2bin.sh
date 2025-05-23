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
	dd if=$REST of=vdp_col.bin  bs=1 count=128 skip=$SKIP conv=notrunc; SKIP=$((SKIP+128))
	dd if=$REST of=vdp_spr0.bin bs=1 count=64  skip=$SKIP conv=notrunc; SKIP=$((SKIP+64 ))
	dd if=$REST of=vdp_spr1.bin bs=1 count=64  skip=$SKIP conv=notrunc; SKIP=$((SKIP+64 ))
	dd if=$REST of=vdp_spr2.bin bs=1 count=64  skip=$SKIP conv=notrunc; SKIP=$((SKIP+64 ))
	divide_files_hi_lo
}

get_regs(){
	tail --bytes $BYTES $REST > regs.bin
}

obtain_mmr_hex(){
	tail --bytes 512 cscn.bin | hexdump -v -e '/2 "%04X\n"' > mmr.hex
}

divide_files_hi_lo(){
	jtutil drop1    < vdp_col.bin  > vdp_col_hi.bin
	jtutil drop1 -l < vdp_col.bin  > vdp_col_lo.bin

	jtutil drop1    < vdp_spr0.bin > spr0_hi.bin
	jtutil drop1 -l < vdp_spr0.bin > spr0_lo.bin

	jtutil drop1    < vdp_spr1.bin > spr1_hi.bin
	jtutil drop1 -l < vdp_spr1.bin > spr1_lo.bin

	jtutil drop1    < vdp_spr2.bin > spr2_hi.bin
	jtutil drop1 -l < vdp_spr2.bin > spr2_lo.bin
}

main $*
