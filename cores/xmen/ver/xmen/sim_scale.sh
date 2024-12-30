#!/bin/bash
jtutil sdram
FIRST=313
LAST=1260
while [ $# -gt 0 ]; do
    case "$1" in
    	1) FIRST=313;LAST=780;;
		2) FIRST=784;LAST=1260;;
		*) echo "Unknown argument $1"; exit 1;;
	esac
	shift
done

jtsim -inputs snd_scale.in -video $LAST -w $FIRST
