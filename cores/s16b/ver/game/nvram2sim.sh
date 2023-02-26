#!/bin/bash
# Use this script to convert NVRAM dumps to simulation input files
# Data order
# VRAM   64kB - part of SDRAM: bank0 at 0x10'0000
# CHAR    4kB - split 16-bit bin dump
# PAL     4kB - split 16-bit bin dump
# OBJRAM  2kB - split 16-bit bin dump

if [ $# = 0 ]; then
cat<<EOF
usage: nvram2sim.sh <MiSTer-dump-file> <scene number>
Call nvram2sim.sh from the simulation scene folder, not the main game folder
EOF
    exit 0
fi

FILE="$1"
SCENE=$2

SCR_START=0
CHAR_START=64
PAL_START=$((CHAR_START+4))
OBJRAM_START=$((PAL_START+4))
BANK_START=$((OBJRAM_START+2))

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

dump scr  $SCR_START 64 || exit $?
dump char $CHAR_START  4 || exit $?
dump pal  $PAL_START  4 || exit $?
dump obj  $OBJRAM_START  2 || exit $?
dd if="$FILE" of=tilebank$SCENE.bin skip=$((BANK_START*1024)) count=1 bs=1

# rm "$FILE"