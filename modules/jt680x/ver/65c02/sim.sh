#!/bin/bash -e

ONLYTEST=
KEEPFILES=--keep

main() {
	parse_args "$@"
	verify_dependencies
	compile_ucode
	run_all_tests
}

parse_args() {
	while [ $# -gt 0 ]; do
		case $1 in
			-h|--help) show_help; exit 0;;
			-s|--show) get_testnames; exit 0;;
			-*) echo "Unsupported argument $1"; exit 1;;
			*)  if [ ! -z "$ONLYTEST" ]; then
					echo "You can only set one test name"
					exit 1
				fi
				ONLYTEST=$1
				KEEPFILES=--keep;;
		esac
		shift
	done
}

show_help() {
	cat<<EOF
Usage sim.sh [args] [test name]

Runs all tests listed in tests.yaml. If called with a test name, it will
only run that test.

-h, --help		displays this screen
-s, --show      shows all test names

EOF
}

verify_dependencies() {
	compile_crasm
	cd ../../testgen
	go build .
	cd - > /dev/null
}

compile_crasm() {
	cd ../../crasm
	local log=`mktemp`
	if ! make > $log; then
		cat $log
		rm -f $log
		exit 1
	fi
	rm -f $log
	cd - > /dev/null
	ln -srf ../../crasm/src/crasm
}

compile_ucode() {
	jtframe ucode --report jt680x 65c02
}

run_all_tests() {
	for testname in `get_testnames`; do
		macros=`../../testgen/jt680x makeTest $testname $KEEPFILES`
		iverilog ../../hdl/jt65c02*.v test.v -o sim $macros -dSIMULATION
		local log=`mktemp`
		sim -lxt > $log
		rm -f sim
		if grep -q PASS $log; then
			printf "%-16s PASS\n" $testname
			rm $log
		else
			printf "%-16s FAIL\n" $testname
			cat $log
			rm $log
			return 1
		fi
	done
	echo "ALL PASS"
}


get_testnames() {
	if [ -z "$ONLYTEST" ]; then
		yq "keys | .[]" tests.yaml
	else
		echo $ONLYTEST
	fi
}

main "$@"