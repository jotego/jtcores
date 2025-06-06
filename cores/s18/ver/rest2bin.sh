#!/bin/bash -e
main(){
	VRAM_OFFSET=$((0x200000))
	SIZE=$((0x10000)) # 64 KiB
	BYTES=$((2+16+256)) # main + video + vdp
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
	parse_file sdram_bank0 "$SIZE" --seek "$VRAM_OFFSET"
}

get_vdp(){
	parse_file vdp "$SIZE"
}

get_vdp_mem(){
	parse_file vdp_sat0  256 --hilo
	parse_file vdp_sat1  256 --hilo
	parse_file vdp_col   128 --hilo
	parse_file vdp_vsram 128 --hilo
	parse_file vdp_spr0   64 --hilo
	parse_file vdp_spr1   64 --hilo
	parse_file vdp_spr2   64 --hilo
}

get_regs(){
	tail --bytes $BYTES $REST > regs.bin
}

obtain_mmr_hex(){
	tail --bytes 512 cscn.bin | hexdump -v -e '/2 "%04X\n"' > mmr.hex
}

parse_file(){
	initialize_variables "$1" "$2"
	shift 2
	parse_args $*
	dd if=$REST of="$OF.bin" bs=1 count=$COUNT conv=notrunc $OTHER
	update_skip
	divide_files_hi_lo
}

initialize_variables(){
	OF="$1";
	COUNT="$2";
	SEEK=
	SKIP_UPDATE=1
	HILO=0
	OTHER=
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
            --hilo)
				HILO=1
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

update_skip(){
	if [[ "$SKIP_UPDATE" == 1 ]]; then
		SKIP=$((SKIP + COUNT))
	fi
}

divide_files_hi_lo(){
	if [[ "$HILO" == 1 ]]; then
		jtutil drop1    < "$OF.bin"  > "${OF}_hi.bin"
		jtutil drop1 -l < "$OF.bin"  > "${OF}_lo.bin"
	fi
}

main $*
