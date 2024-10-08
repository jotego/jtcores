#!/bin/bash
jtutil sdram
FIRST=313
LAST=1577
# x-men sample at 795
# music starts at 863
while [ $# -gt 0 ]; do
    case "$1" in
    	1) FIRST=313;LAST=795;;
		2) FIRST=795;LAST=1577;;
		*) echo "Unknown argument $1"; exit 1;;
	esac
	shift
done

jtsim -video $LAST -w $FIRST
mv test.fst demo.fst
mv test.wav demo.wav