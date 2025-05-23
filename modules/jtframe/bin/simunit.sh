#!/bin/bash -e
# use to simulate unit tests
# create a file called gather.f with the names of the files to include in the sim
# not local to the simulation folder

main() {
	parse_args $*
	cd_to_run_folder
	parse_dot_simunit
	if [ -z "$ALL_MACROS" ]; then
		run_one
	else
		loop_macros
	fi
	exit_with_status
}

parse_args() {
	RUNFOLDER="."
	ALL_MACROS=
	MACRO=
	FAIL=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--keep)	  KEEP_LXTFILE=1;;
			--run)    shift; RUNFOLDER="$1";;
			--macros) shift; ALL_MACROS="$1";;
			--help|-h) show_help; exit 0;;
			*)
				echo "Unsupported argument $1"
				exit 1;;
		esac
		shift
	done
}

show_help() {
	cat <<EOF
simunit.sh: run unit simulations

--keep		do not delete test.lxt after a PASS simulation
--macros	comma separated list of macros. Each macro will trigger a different
            simulation.
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

run_one() {
	prepare_files
	lint_uut
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
	verilator --lint-only -f $GATHER --top-module $top $macro
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
		macro="-D $MACRO"
	fi
	if [[ $macro != *JTFRAME_MCLK* ]]; then
		macro="$macro -D JTFRAME_MCLK=48000000"
	fi
	iverilog -g2012 `find -name "*.v"` `find -name "*.sv"` \
		-I$JTFRAME/ver/inc \
		$JTFRAME/hdl/{video/jtframe_vtimer.v,ver/jtframe_test_clocks.v} \
		-f$GATHER -s test -o sim -D SIMULATION $macro
	sim -lxt > sim.log
}

eval_result() {
	if grep PASS sim.log > /dev/null; then
		echo PASS
	else
		cat sim.log
		echo FAIL
		FAIL=1
	fi
}

clean_up() {
	rm -f sim $GATHER sim.log
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

main $*
