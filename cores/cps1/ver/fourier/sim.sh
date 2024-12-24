#!/bin/bash

set -e

if [ ! -e $ROM/sf2ua.rom ]; then
	jtframe mra cps1
fi

rm -f rom.bin
bspatch $ROM/sf2ua.rom rom.bin mdf.patch