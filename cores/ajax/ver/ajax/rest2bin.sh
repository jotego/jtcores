#!/bin/bash -e
main(){
	REST="rest.bin"
	SKIP=0

	get_scroll
	get_pal
	get_psac
	get_obj
	get_psac_mmr
	get_scr_mmr
	get_obj_mmr
	get_prio
}

get_scroll(){
	parse_file scr1 8192
	parse_file scr0 8192
}

get_pal(){
	parse_file pal 4096
}

get_psac(){
	parse_file psac0 1024
	parse_file psac1 1024
}

get_obj(){
	parse_file obj 1024
}

get_psac_mmr(){
	parse_file psac_mmr 16
}

get_scr_mmr(){
	parse_file scr_mmr  8
}

get_obj_mmr(){
	parse_file obj_mmr  7
}

get_prio(){
	tail --bytes 1 $REST > prio.bin
}

parse_file(){
	initialize_variables "$1" "$2"
	shift 2
	parse_args $*
	dd if=$REST of="$OF.bin" bs=1 count=$COUNT $OTHER
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
