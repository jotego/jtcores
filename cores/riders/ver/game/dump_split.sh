#!/bin/bash -e
main(){
	parse_split_args $*
	check_scene_dir
	set_input_file

	get_nvram    # 128 bytes
	get_psac     # 2  kB
	get_scroll   # 16 kB or 24 kB
	get_pal      # 4  kB
	get_obj      # 8  kB or 16 kB
	get_psac_mmr # 32 bytes
	get_pal_mmr  # 16 bytes
	get_scr_mmr  # 8  bytes
	get_obj_mmr  # 8  bytes
	get_other    # 1  byte
}

parse_split_args(){
	SCENE=
	FNAME=
	IF=
	NVRAM=0
	FULLRAM=0
	FULLOBJ=0
	DUALPAL=0
	PSAC=0
	PSAC_MMR=0
	SKIP=0
	VERBOSE=0

	while [ $# -gt 0 ]; do
	    case $1 in
	        -s|--scene)
	            shift
	            SCENE=$1;;
	        -f|--file)
				shift
				FNAME=$1;;
			-v|--nvram)
				NVRAM=1;;
			-x|--fullram)
				FULLRAM=1;;
			-o|--fullobj)
				FULLOBJ=1;;
			-p|--pal2)
				DUALPAL=1;;
			-ps|--psac)
				PSAC=1;;
			-pmmr|--psac_mmr)
				PSAC_MMR=1;;
			-fps|--fullpsac)
				PSAC=1
				PSAC_MMR=1;;
			--verbose)
				VERBOSE=1;;
	        *) OTHER="$OTHER $1";;
	    esac
	    shift
	done
}

check_scene_dir(){
	if [ -z "$SCENE" ]; then
		SCENE=.
	else
		SCENE=scenes/$SCENE
	fi
}

set_input_file(){
	if [ -z "$FNAME" ]; then
		FNAME=$(basename $(pwd))
		IF_NAMES=("${FNAME^^}.RAM" "${FNAME}.sav" "dump.bin")
		for name in "${IF_NAMES[@]}"; do
			if [[ -f "$SCENE/$name" ]]; then
				FNAME=$name
				break
			else
				FNAME=
			fi
		done
		if [[ -z "$FNAME" ]]; then
			echo "Cannot determine direction for scene data. Exitting"
			exit 0
		fi
	fi
	IF="$SCENE/$FNAME"
	echo "Using $FNAME as file name for scene data"
}

clear_old_files(){
	rm -f {scr?,pal,obj_??,???_mmr}.bin
}

get_nvram(){
	if [ $NVRAM = 1 ]; then
		parse_file nvram 128
	fi
}

get_psac(){
	if [[ $PSAC = 1 ]]; then
		parse_file line 2048 --hilo
	fi
}

get_scroll(){
	parse_file scr1 8192
	parse_file scr0 8192
	if [ $FULLRAM = 1 ]; then
		parse_file scrx 8192
	fi
}

get_pal(){
	if [ $DUALPAL=1 ]; then
		DUAL=--hilo
	else
		DUAL=""
	fi
	parse_file pal 4096 $DUAL
}

get_obj(){
	if [ $FULLOBJ = 1 ]; then
		parse_file obj 16384 --hilo
	else
		parse_file obj 8192  --hilo
	fi
}

# MMR
get_psac_mmr(){
	if [ $PSAC_MMR = 1 ]; then
		parse_file psac 32
	fi
}

get_pal_mmr(){
	parse_file pal_mmr 16
}

get_scr_mmr(){
	parse_file scr_mmr 8
}
get_obj_mmr(){
	parse_file obj_mmr 8
}

get_other(){
	parse_file other 1
}

parse_file(){
	initialize_variables "$1" "$2"
	shift 2
	parse_args $*
	if [[ $VERBOSE = 1 ]]; then echo "Parsing ${OF}.bin for $COUNT bytes. Skipping $SKIP bytes"; fi
	dd if=$IF of="$OF.bin" bs=1 count=$COUNT $OTHER
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