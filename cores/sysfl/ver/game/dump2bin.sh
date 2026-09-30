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
	# backup 8192 bytes (8 kB)
	rm -f backup.bin
	dd if="$DUMP" of=backup.bin bs=64 count=128 skip=0
	jtutil drop1    < backup.bin > backup_hi.bin
	jtutil drop1 -l < backup.bin > backup_lo.bin
	
	# vram 65536 bytes (64 kB)
	rm -f vram.bin
	dd if="$DUMP" of=vram.bin bs=64 count=1024 skip=128
	jtutil drop1    < vram.bin > vram_hi.bin
	jtutil drop1 -l < vram.bin > vram_lo.bin
	
	# rozram 131072 bytes (128 kB)
	rm -f rozram.bin
	dd if="$DUMP" of=rozram.bin bs=64 count=2048 skip=1152
	jtutil drop1    < rozram.bin > rozram_hi.bin
	jtutil drop1 -l < rozram.bin > rozram_lo.bin
	
	# oram 131072 bytes (128 kB)
	rm -f oram.bin
	dd if="$DUMP" of=oram.bin bs=64 count=2048 skip=3200
	jtutil drop1    < oram.bin > oram_hi.bin
	jtutil drop1 -l < oram.bin > oram_lo.bin
	
	# rpal 8192 bytes (8 kB)
	rm -f rpal.bin
	dd if="$DUMP" of=rpal.bin bs=64 count=128 skip=5248
	
	# gpal 8192 bytes (8 kB)
	rm -f gpal.bin
	dd if="$DUMP" of=gpal.bin bs=64 count=128 skip=5376
	
	# bpal 8192 bytes (8 kB)
	rm -f bpal.bin
	dd if="$DUMP" of=bpal.bin bs=64 count=128 skip=5504
	
	
	make_rest
}

delete_parts() {
	rm -f backup.bin
	rm -f backup_hi.bin backup_lo.bin
	
	rm -f vram.bin
	rm -f vram_hi.bin vram_lo.bin
	
	rm -f rozram.bin
	rm -f rozram_hi.bin rozram_lo.bin
	
	rm -f oram.bin
	rm -f oram_hi.bin oram_lo.bin
	
	rm -f rpal.bin
	
	rm -f gpal.bin
	
	rm -f bpal.bin
	
	
	rm -f rest.bin
	run_core_specific_script --delete
}

make_rest() {
	dd if="$DUMP" of=rest.bin bs=64 skip=5632
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
