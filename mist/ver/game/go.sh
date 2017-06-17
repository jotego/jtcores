#!/bin/bash

function zero_file {
	rm -f $1
	cnt=$2
	while [ $cnt != 0 ]; do
		echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
		cnt=$((cnt-16))
	done;
}

if ! lwasm gng_test.s --output=gng_test.bin --list=gng_test.lst --format=raw; then
	exit 1
fi

OD="od -t x1 -A none -v -w1"

$OD gng_test.bin > ram.hex
zero_file 10n.hex 16384
zero_file 13n.hex $((2*16384))

DUMP=NODUMP
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO

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
	echo "Unknown option $1"
	exit 1
done

iverilog game_test.v \
	../../hdl/*.v \
	../../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s game_test -o sim \
	-D$DUMP -D$CHR_DUMP -D$RAM_INFO -DSIMULATION\
&& sim -lxt