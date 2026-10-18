#!/bin/bash

main() {
	if [[ ${1:-} == --delete ]]; then
		rm -f mmr0.bin mmr1.bin ommr.bin other.bin
		return
	fi
	split_parts
}

split_parts() {
	dd if=rest.bin of=mmr0.bin  bs=8 count=1
	dd if=rest.bin of=mmr1.bin  bs=8 count=1 skip=1
	dd if=rest.bin of=ommr.bin  bs=4 count=1 skip=4
	dd if=rest.bin of=other.bin bs=1 count=2 skip=20
}

main "$@"
