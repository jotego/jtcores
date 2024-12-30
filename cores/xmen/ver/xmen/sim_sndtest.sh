#!/bin/bash
jtutil sdram
LAST=540
# voice test 1 finishes at 447
# voice test 2 finishes at 540
while [ $# -gt 0 ]; do
		case "$1" in
			1) LAST=447;;
			2) LAST=540;;
			*) echo "Unknown argument $1"; exit 1;;
	esac
	shift
done

jtsim -inputs snd_test.in -video $LAST -w 332
mv test.fst sndtest.fst
mv test.wav sndtest.wav
