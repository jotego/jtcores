#!/bin/bash
if [ ! -e rom.bin ]; then
	ln -sr /home/jtejada/jtcores/rom/cps3_syscheck.rom rom.bin
fi
jtsim -load -video 10 -w -d VERILATOR_KEEP_CPU $*
