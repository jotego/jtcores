#!/bin/bash
if [ ! -e mcu.bin ]; then
	unzip ~/.mame/roms/bublbobl.zip a78-01.17
	mv a78-01.17 mcu.bin
fi

if [ ! -e main.bin ]; then
	unzip ~/.mame/roms/bublbobl.zip a78-06-1.51
	mv a78-06-1.51 main.bin
	unzip ~/.mame/roms/bublbobl.zip a78-05-1.52
	cat a78-05-1.52 >> main.bin
fi

if [ ! -e sub.bin ]; then
	unzip ~/.mame/roms/bublbobl.zip a78-08.37
	mv a78-08.37 sub.bin
fi

if [ ! -e snd.bin ]; then
	unzip ~/.mame/roms/bublbobl.zip a78-07.46
	mv a78-07.46 snd.bin
fi

jtsim "$@"	
