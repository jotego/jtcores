#!/bin/bash -e
# use to simulate unit tests
# create a file called gather.f with the names of the files to include in the sim
# not local to the simulation folder

main() {
	parse_args $*
	cd_to_run_folder
	prepare_files
	lint_uut
	run_simulation
	eval_result
	clean_up
	exit_with_status
}

parse_args() {
	RUNFOLDER="$1"
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
	local top
	top=`get_top_module`
	verilator --lint-only -f $GATHER --top-module $top
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
	iverilog -g2012 `find -name "*.v"` `find -name "*.sv"` \
		-I$JTFRAME/ver/inc \
		$JTFRAME/hdl/{video/jtframe_vtimer.v,ver/jtframe_test_clocks.v} \
		-f$GATHER -s test -o sim -D SIMULATION
	sim -lxt > sim.log
}

eval_result() {
	if grep PASS sim.log > /dev/null; then
		echo PASS
		FAIL=0
	else
		cat sim.log
		echo FAIL
		FAIL=1
	fi
}

clean_up() {
	rm -f sim $GATHER sim.log
	if [ $FAIL = 0 ]; then
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
