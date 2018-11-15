#!/bin/bash

EXTRA=
GATHER=gather_dummy.f

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		EXTRA="$EXTRA -trace"
		echo Signal dump enabled
		shift
		continue
	fi
	if [ "$1" = "-time" ]; then
		shift
		if [ "$1" = "" ]; then
			echo "Must specify number of milliseconds to simulate"
			exit 1
		fi
		SIM_MS="$1"
		echo Simulate $1 ms
		shift
		continue
	fi	
	if [ "$1" = -lint ]; then
		verilator -f gather.f --lint-only --top-module jtgng_sound --error-limit 500
		exit $?
	fi	
	echo "Unknown option $1"
	exit 1
done

if ! verilator --cc -f $GATHER --top-module jtgng_sound --trace --exe test.cpp \
	-DFASTDIV -DNOLFO -DNOTIMER --trace-depth 1; then
	exit $?
fi

if ! make -j -C obj_dir -f Vjtgng_sound.mk Vjtgng_sound; then
	exit $?
fi

obj_dir/Vjtgng_sound $EXTRA
if [ -e test.vcd ]; then
	vcd2fst -v test.vcd -f test.fst && rm test.vcd
fi