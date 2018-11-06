#!/bin/bash

DUMP=

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		DUMP=-trace
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

verilator --cc -f gather.f --top-module jtgng_sound --trace --exe test.cpp

if ! make -j -C obj_dir -f Vjtgng_sound.mk Vjtgng_sound; then
	exit $?
fi