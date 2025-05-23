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
	parse_file sdram_bank0.bin "$SIZE" --seek "$VRAM_OFFSET"
}

get_vdp(){
	parse_file vdp.bin "$SIZE"
}

get_vdp_mem(){
	parse_file vdp_col.bin  128
	parse_file vdp_spr0.bin  64
	parse_file vdp_spr1.bin  64
	parse_file vdp_spr2.bin  64
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

parse_file(){
	# Declare variables
	OF=$1; 	  shift
	COUNT=$1; shift
	OTHER=
	SEEK=
	SKIP_UPDATE=1

	parse_args $*
	dd if=$REST of="$OF" bs=1 count=$COUNT conv=notrunc $OTHER
	update_skip
}

update_skip(){
	if [[ "$SKIP_UPDATE" == 1 ]]; then
		SKIP=$((SKIP + COUNT))
	fi
}
parse_args(){
	while [[ $# -gt 0 ]]; do
        case "$1" in
            --seek)
				shift
                SEEK=$1
                ;;
            --no-skip)
                SKIP_UPDATE=0
                ;;
            *)
                OTHER+=" $1"
                ;;
        esac
        shift
    done

	if [[ ! -z $SEEK ]]; then
		OTHER+=" seek=$SEEK"
	else
		OTHER+=" skip=$SKIP"
	fi
}

main $*
