#!/bin/bash

BLOCKID=NOBLOCKID

while [ $# -gt 0 ]; do
	echo "Unknown option $1"
	exit 1
done

g++ char_ram.cc -o char_ram && char_ram

iverilog stim.v test.v ../../hdl/jtgng_{video,char,scroll,obj,colmix,rom,timer,sh,ram,dual_ram,true_dual_ram}.v \
    ../common/mt48lc16m16a2.v -o sim -D$BLOCKID -DSIMULATION\
	&& sim -lxt