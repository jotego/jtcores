#!/bin/bash

if [ "$1" = "-w" ]; then
	DUMP=DUMP
	echo Signal dump enabled
else
	echo Signal dump disabled
	DUMP=NODUMP
fi

iverilog jt_gng_test.v \
	../../hdl/*.v \
	../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s jt_gng_test -o sim -D$DUMP \
&& sim -lxt