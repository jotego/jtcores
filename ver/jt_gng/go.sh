#!/bin/bash

DUMP=NODUMP
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
LOCALROM=
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
	if [ "$1" = "-local" ]; then
		LOCALROM=-DLOCALROM
		if [ ! -e gng_test.s ]; then
			echo "Local ROM requested but no gng_test.s file found for assembly"
			exit 1
		fi
		echo Local ROM enabled
		shift
		continue
	fi	
	echo "Unknown option $1"
	exit 1
done

if [ LOCALROM != "" ]; then
	if [ ! -e 10n.hex ]; then touch 10n.hex; fi
	if [ ! -e 13n.hex ]; then touch 13n.hex; fi
	if ! lwasm gng_test.s --output=gng_test.bin --list=gng_test.lst --format=raw; then
		exit 1
	fi
	OD="od -t x1 -A none -v -w1"
	$OD gng_test.bin > 8n.hex
fi

iverilog jt_gng_test.v \
	../../hdl/*.v \
	../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s jt_gng_test -o sim \
	-D$DUMP -D$CHR_DUMP -D$RAM_INFO -DREPS=$REPS $LOCALROM\
&& sim -lxt