#!/bin/bash

DUMP=NODUMP
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
REPS=1

while [ $# -gt 0 ]; do
	if [ "$1" = "-w" ]; then
		DUMP=DUMP
		echo Signal dump enabled
		shift
		continue
	fi
	if [ "$1" = "-ch" ]; then
		CHR_DUMP=CHR_DUMP
		echo Character dump enabled
		shift
		continue
	fi
	if [ "$1" = "-info" ]; then
		RAM_INFO=RAM_INFO
		echo RAM information enabled
		shift
		continue
	fi
	if [ "$1" = "-reps" ]; then
		shift
		REPS=$1
		shift
		continue
	fi
	echo "Unknown option $1"
	exit 1
done

iverilog game_test.v \
	../../hdl/*.v \
	../../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s game_test -o sim \
	-D$DUMP -D$CHR_DUMP -D$RAM_INFO -DREPS=$REPS\
&& sim -lxt