#!/bin/bash

BLOCKID=NOBLOCKID

while [ $# -gt 0 ]; do
	echo "Unknown option $1"
	exit 1
done

if ! g++ char_ram.cc -o char_ram; then
    exit 1
fi
char_ram

iverilog stim.v test.v ../../hdl/jtgng_{video,char,scroll,obj,colmix,rom,timer,sh,ram,dual_ram,true_dual_ram}.v \
    -o sim -D$BLOCKID -DSIMULATION\
	&& sim -lxt