#!/bin/bash
if [ ! -e mcu.bin ]; then
	unzip ~/.mame/roms/bublbobl.zip a78-01.17
	mv a78-01.17 mcu.bin
fi

jtsim "$@"	
