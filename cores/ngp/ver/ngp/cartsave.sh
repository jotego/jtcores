#!/bin/bash -e
main(){
	parse_split_args "$@"


	find_cart_name
	find_save_file
	set_saveparams
	# set_input_file
#
	# get_nvram    # 128 bytes
	# get_psac     # 2  kB
	# get_scroll   # 16 kB or 24 kB
	# get_pal      # 4  kB
	# get_obj      # 8  kB or 16 kB
	# get_psac_mmr # 32 bytes
	# get_pal_mmr  # 16 bytes
	# get_scr_mmr  # 8  bytes
	# get_obj_mmr  # 8  bytes
	# get_other    # 1  byte

	call_jtsim
}

parse_split_args(){
	FNAME=
	IF0=
	IF1=
	OF="cart.rom"
	ROMEXT="ngc"
	SAVEXT="sav"
	MIN=0
	MAX=$((0x1FFF))
	BSIZE=256
	SBLOCKS=1
	SKIPSAVE=0
	VERBOSE=0
	OTHER=""

	while [ $# -gt 0 ]; do
	    case "$1" in
	        -g|--game)
	            shift
	            FNAME="$1";;
	        -c|--cart)
	            shift
	            IF0="$1";;
	        -s|--save)
	            shift
	            IF1="$1";;
	        --skip)
	            SKIPSAVE=1;;
			--verbose)
				VERBOSE=1;;
	        *) OTHER="$OTHER $1";;
	    esac
	    shift
	done
}

find_cart_name(){
	if [ -z "$IF0" ]; then
		if [ -z "$FNAME" ]; then
			echo "Could not determine game name. Provide a name to look for cartridge using --game"
			exit 0
		fi
		matches=("carts/${FNAME}"*"${ROMEXT}")
		if [[ $matches == *"*${ROMEXT}" ]]; then
			echo "No match found for '$FNAME'"
			exit 0
		elif [[ "${#matches[@]}" -gt 1 ]]; then
			echo "More than one match found for '$FNAME':"
			printf '%s\n' "${matches[@]}"
			exit 0
		else
			IF0="$matches"
			if [[ $VERBOSE == 1 ]]; then
				echo "Found ${IF0} as cartridge"
			fi
		fi
	fi
}

find_save_file(){
	if [ -z "$IF1" ]; then
		if [ -z "$FNAME" ]; then
			echo "Could not determine game name. Provide a name to look for cartridge using --game"
			exit 0
		fi
		smatch=("saves/${FNAME}"*"${SAVEXT}")
		if [[ $smatch == *"*${SAVEXT}" ]]; then
			echo "No save file found for '$FNAME'"
			exit 0
		elif [[ "${#smatch[@]}" -gt 1 ]]; then
			echo "More than one save file found for '$FNAME':"
			printf '%s\n' "${smatch[@]}"
			exit 0
		else
			IF1="$smatch"
			if [[ $VERBOSE == 1 ]]; then
				echo "Found ${IF1} as save file"
			fi
		fi
	fi
}

get_minmax(){
	MAX=$(hexdump -n2 -e '1/2 "%u"'      "$IF1" )
	MIN=$(hexdump -n2 -e '1/2 "%u"' -s 2 "$IF1" )
	SBLOCKS=$(($MAX - $MIN + $SBLOCKS))
	if [[ $VERBOSE == 1  ]]; then
		echo "Min   block:  $MIN  Max block: $MAX"
		echo "Total blocks: $SBLOCKS"
	fi
}

prepare_new_file(){
	dd if="$IF0" of="$OF" bs="$BSIZE" count="$MIN"                                           status=none
	dd if="$IF1" of="$OF" bs="$BSIZE" count="$SBLOCKS" skip=1             seek="$MIN"        status=none
	dd if="$IF0" of="$OF" bs="$BSIZE"                  skip="$(($MAX+1))" seek="$(($MAX+1))" status=none
	if [[ $VERBOSE == 1  ]]; then
		echo "Created $OF"
	fi
}

set_saveparams(){
	if [[ $SKIPSAVE == 0  ]]; then
		get_minmax
		prepare_new_file
	else
		OF=$IF0
	fi
	if [[ $VERBOSE == 1  ]]; then
		echo "Using $OF as cartridge for simulation"
	fi
}

call_jtsim(){
	if [[ $VERBOSE == 1  ]]; then
		echo "sim.sh -cart $OF $OTHER"
	fi
	./sim.sh -cart "${OF}" $OTHER
}

main "$@"