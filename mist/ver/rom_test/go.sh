#!/bin/bash

BLOCKID=NOBLOCKID

while [ $# -gt 0 ]; do
	if [ "$1" = "-b" ]; then
		BLOCKID=BLOCKID
		echo ROM block ID operation enabled
		shift
		continue
	fi
	echo "Unknown option $1"
	exit 1
done

iverilog rom_test.v ../../hdl/jtgng_rom.v ../common/mt48lc16m16a2.v -o sim -D$BLOCKID \
	&& sim -lxt