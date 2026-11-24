#!/bin/bash -e

main() {
	if [[ ${1:-} == --delete ]]; then
		rm -f seta_cfg.hex
		return
	fi
	check_size
	extract_seta_config
}

check_size() {
	local expected=12
	local actual
	actual=$(wc -c < rest.bin)
	if [[ $actual -ne $expected ]]; then
		echo "wrong size for rest.bin. Expected $expected bytes but got $actual"
		exit 1
	fi
}

extract_seta_config() {
	dd if=rest.bin bs=1 skip=8 count=4 status=none | od -An -v -tx1 | tr ' ' '\n' | sed '/^$/d' > seta_cfg.hex
}

main "$@"
