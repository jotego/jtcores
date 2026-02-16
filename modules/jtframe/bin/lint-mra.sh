#!/bin/bash

FAIL=false
BROKEN=()

main() {
	test_mra_generation
	print_summary
	if $FAIL; then
		exit 1
	fi
}

test_mra_generation() {
	local tmp=`mktemp`
	for core in $CORES/*; do
		rm -f $tmp
		if [ ! -d $core ]; then continue; fi
		if [ ! -e $core/cfg/mame2mra.toml ]; then continue; fi
		core=`basename $core`
		jtframe mra $core --skipROM --skipPocket > $tmp && continue
		echo $core
		cat $tmp
		BROKEN+=($core)
		FAIL=true
	done
	rm -f $tmp
}

print_summary() {
	if ! $FAIL; then
		echo PASS;
		return;
	fi
	for core in ${BROKEN[@]}; do
		echo $core
	done
	echo FAIL
}

main "$@"