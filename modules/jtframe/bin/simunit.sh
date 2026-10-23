#!/bin/bash -e
# use to simulate unit tests
# create a file called gather.f with the names of the files to include in the sim
# not local to the simulation folder

set -o pipefail

RUNFOLDER="."
ALL_MACROS=
MACRO=
FAIL=0
SIMULATOR=iverilog
VERILATOR_BUILD=

main() {
	parse_args "$@"
	cd_to_run_folder
	parse_dot_simunit
	parse_args "$@"
	trap clean_temp EXIT
	execute_goscript
	if [ -z "$ALL_MACROS" ]; then
		run_one
	else
		loop_macros
	fi
	exit_with_status
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--keep)	  KEEP_LXTFILE=1;;
			--run)    shift; RUNFOLDER="$1";;
			--skip)   exit_if_running_on_github;;
			--macros) shift; ALL_MACROS="$1";;
			--simulator)
				shift
				case "${1:-}" in
					iverilog|verilator) SIMULATOR="$1";;
					*) echo "Use --simulator iverilog or verilator"; exit 1;;
				esac;;
			--help|-h) show_help; exit 0;;
			*)
				echo "Unsupported argument $1"
				exit 1;;
		esac
		shift
	done
}

exit_if_running_on_github() {
	if [ "$GITHUB_ACTIONS" = "true" ]; then
		echo "This simulation is skipped when run on GitHub"
		echo "PASS"
		exit 0
	fi
}

show_help() {
	cat <<EOF
simunit.sh: run unit simulations

Create a .simunit file to indicate that the testbench is compatible with
simunit.sh. This file can contain arguments to simunit.sh in its first line.

If a init.go file exists, it will run before simulation with the command

go run init.go

If a clean_up.sh file exists, it will run during cleanup with the command

bash ./clean_up.sh

Arguments:

--simulator     iverilog (default) or verilator
--keep		do not delete test.lxt after a PASS simulation
--macros	comma separated list of macros. Each macro will trigger a different
            simulation.
--skip		skip this test in GitHub actions
--run		sets run folder
--help, -h	this help
EOF
}

parse_dot_simunit() {
	if [ -s .simunit ]; then
		local top_line
		top_line=`head --lines 1 .simunit`
		parse_args $top_line
	fi
}

execute_goscript() {
	if [ ! -e init.go ]; then return; fi
	go run init.go
}

run_one() {
	prepare_files
	if [ "$SIMULATOR" = iverilog ]; then lint_uut; fi
	run_simulation
	eval_result
	clean_up
}

loop_macros() {
	for MACRO in `expand_comma_list $ALL_MACROS`; do
		printf "%-32s" "$MACRO"
		run_one
	done
}

expand_comma_list() {
	local list="$1"
	echo $list | tr , ' '
}

cd_to_run_folder() {
	if [ -z "$RUNFOLDER" ]; then
		RUNFOLDER=`pwd`
	fi

	cd $RUNFOLDER
	echo "Running from `pwd`"
}

prepare_files() {
	GATHER=`mktemp`
	envsubst < gather.f > $GATHER
	echo >> $GATHER	# extra blank line
	copy_hex_files
	filter_hex_out
}

lint_uut() {
	local macro
	if [ ! -z "$MACRO" ]; then
		macro="-D$MACRO"
	fi
	local top
	top=`get_top_module`
	if [[ $macro != *JTFRAME_MCLK* ]]; then
		macro="$macro -DJTFRAME_MCLK=48000000"
	fi
	verilator --quiet --lint-only -Wno-TIMESCALEMOD -f $GATHER --top-module $top $macro
}

get_top_module() {
	local top_line filename module
	top_line=`head -n 1 $GATHER`
	filename=`basename $top_line`
	module=${filename%.*}
	echo $module
}

copy_hex_files() {
	for i in `grep hex$ $GATHER`; do
		cp $i .
	done
}

filter_hex_out() {
	sed -i /hex$/d $GATHER
}

run_simulation() {
	local macro
	if [ ! -z "$MACRO" ]; then
		macro="-D$MACRO"
	fi
	if [[ $macro != *JTFRAME_MCLK* ]]; then
		macro="$macro -DJTFRAME_MCLK=48000000"
	fi
	if [ "$SIMULATOR" = verilator ]; then
		run_verilator $macro
		return
	fi
	iverilog -g2012 `find -name "*.v"` `find -name "*.sv"` \
		-I$JTFRAME/ver/inc \
		$JTFRAME/hdl/{video/jtframe_vtimer.v,ver/jtframe_test_clocks.v} \
		-f$GATHER -s test -o sim -D SIMULATION $macro
	sim -lxt | tee sim.log
}

run_verilator() {
	local trace=()
	if [ -n "$KEEP_LXTFILE" ]; then trace=(--trace); fi
	mkdir -p obj_dir
	VERILATOR_BUILD=$(mktemp -d "$PWD/obj_dir/simunit.XXXXXX")
	verilator --binary --timing -j 2 --top-module test \
		--Mdir "$VERILATOR_BUILD" -o sim "${trace[@]}" \
		-Wno-fatal -Wno-TIMESCALEMOD \
		-DSIMULATION "$@" -f "$GATHER" \
		`find -name "*.v"` `find -name "*.sv"` \
		-I. -I"$JTFRAME/ver/inc" \
		$JTFRAME/hdl/{video/jtframe_vtimer.v,ver/jtframe_test_clocks.v}
	"$VERILATOR_BUILD/sim" | tee sim.log
}

clean_temp() {
	if [ -n "$GATHER" ]; then
		rm -f -- "$GATHER"
		GATHER=
	fi
	if [ -n "$VERILATOR_BUILD" ]; then
		rm -rf -- "$VERILATOR_BUILD"
		VERILATOR_BUILD=
	fi
}

eval_result() {
	if grep -q PASS sim.log && ! grep -Eq '(^|[[:space:]])FAIL([[:space:]:]|$)|%Fatal|%Error' sim.log; then
		echo PASS
	else
		cat sim.log
		echo FAIL
		FAIL=1
	fi
}

clean_up() {
	if [ -e clean_up.sh ]; then
		bash ./clean_up.sh
	fi
	rm -f sim sim.log
	clean_temp
	if [[ $FAIL = 0 && -z "$KEEP_LXTFILE" ]]; then
		rm -f test.lxt
	fi
}

exit_with_status() {
	if [ $FAIL = 1 ]; then
		exit 1;
	else
		exit 0
	fi
}

main "$@"
