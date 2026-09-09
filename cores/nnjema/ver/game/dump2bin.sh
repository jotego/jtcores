#!/bin/bash -e

DUMP=dump.bin
DELETE=

main() {
	parse_args "$@"
	if [ -n "$DELETE" ]; then
		delete_parts
		return
	fi
	require_input_file
	split_into_parts
	run_core_specific_script
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--delete) DELETE=1;;
			*) DUMP="$1";;
		esac
		shift
	done
}

require_input_file() {
	if [ ! -e "$DUMP" ]; then
		echo "Cannot find $DUMP"
		return 1
	fi
}

split_into_parts() {
	# vcode 1024 bytes (1 kB)
	rm -f vcode.bin
	dd if="$DUMP" of=vcode.bin bs=64 count=16 skip=0
	
	# vattr 1024 bytes (1 kB)
	rm -f vattr.bin
	dd if="$DUMP" of=vattr.bin bs=64 count=16 skip=16
	
	# oram 512 bytes (0 kB)
	rm -f oram.bin
	dd if="$DUMP" of=oram.bin bs=64 count=8 skip=32
	
	
	make_rest
}

delete_parts() {
	rm -f vcode.bin
	
	rm -f vattr.bin
	
	rm -f oram.bin
	
	
	rm -f rest.bin
	run_core_specific_script --delete
}

make_rest() {
	dd if="$DUMP" of=rest.bin bs=64 skip=40
}

run_core_specific_script() {
	local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	for path in $script_path/. $script_path/..; do
		if [ -x $path/rest2bin.sh ]; then
			echo $path/rest2bin.sh
			$path/rest2bin.sh "$@"
			return
		fi
	done
}

main "$@"
