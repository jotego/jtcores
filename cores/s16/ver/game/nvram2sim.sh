#!/bin/bash
# Use this script to convert NVRAM dumps to simulation input files
# Data order
# VRAM   32kB - part of SDRAM: bank0 at 0x10'0000
# CHAR    4kB - split 16-bit bin dump
# PAL     4kB - split 16-bit bin dump
# OBJRAM  2kB - split 16-bit bin dump

FILE="$1"
SCENE=$2

SCR_START=0
CHAR_START=32
PAL_START=36
OBJRAM_START=40

if [ $(basename `pwd`) = game ]; then
    echo "Call this script from the simulation scene folder"
    exit 1
fi

if [ ! -e "$FILE" ]; then
    echo "Cannot open file $FILE"
    exit 1
fi

if [ -z "$SCENE" ]; then
    echo "You need to specify the simulation scene for the output files"
    exit 1
fi

function dump {
    dd if="$FILE" of=$1$SCENE.bin skip=$2 count=$3 bs=1024

}

dump scr  $SCR_START 32 || exit $?
dump char $CHAR_START  4 || exit $?
dump pal  $PAL_START  4 || exit $?
dump obj  $OBJRAM_START  2 || exit $?

# rm "$FILE"