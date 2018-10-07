#!/bin/bash

DUMP=DUMP
SIM_MS=1

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		DUMP=DUMP
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
	echo "Unknown option $1"
	exit 1
done

iverilog jtgng_sound_tb.v \
	-I../../../modules/jt12/hdl/ \
	../../hdl/*.v \
	../common/{mt48lc16m16a2.v,altera_mf.v} \
	../../../modules/tv80/*.v \
	../../../modules/jt12/hdl/*.v \
	../../../modules/jt12/ver/common/sep24.v \
	-s jtgng_sound_tb -o sim \
	-D$DUMP -DSIM_MS=$SIM_MS\
&& vvp sim -lxt