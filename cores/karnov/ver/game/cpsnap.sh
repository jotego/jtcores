#!/bin/bash

if [ $# != 3 ]; then
    echo "cpsnap.sh SCENE SCRH SCRV"
    exit 1
fi

mkdir -p "$1"
cp ~/.mame/vram.bin $1
cp ~/.mame/scrram.bin $1
cp ~/.mame/objram.bin $1

SCRH=$2
SCRV=$3

if [ $# = 3 ]; then
	echo -e $SCRH\\n$SCRV > $1/scrpos.hex
fi
