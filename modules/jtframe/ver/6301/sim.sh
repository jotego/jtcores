#!/bin/bash

set -e
# use with any .asm file in this directory
ASM=$1
if [[ -z "$ASM" || ! -e $ASM.asm ]]; then
	echo "Cannot find $ASM.asm"
	echo "Use it with:"
	ls *.asm
	exit 1
fi

asl -L -cpu 6301 $ASM.asm
p2bin $ASM.p
rm -f $ASM.p
mv $ASM.bin test.bin
mv $ASM.lst test.lst
iverilog -g2005-sv ../../hdl/cpu/6801_core.sv test.v -o sim
sim -lxt
