#!/bin/bash

# Video simulation

SCENE=SCONTRA.RAM
OTHER=

while [ $# -gt 0 ]; do
    case $1 in
        -s|-scene)
            shift
            SCENE=$1;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

if [ ! -e $SCENE ]; then
    echo "Generate $SCENE on MiST by saving the NVRAM"
    echo "And copying SCONTRA.RAM from MiST's SD card to here"
    exit 0
fi

NULLDD="dd status=none if=$SCENE"

# 16 kB Tilemap VRAM
$NULLDD of=scr1.bin count=16
$NULLDD of=scr0.bin count=16 skip=16
# 2 kB PAL
$NULLDD of=pal.bin count=4 skip=32
# 1 kB Sprite LUT
$NULLDD of=obj.bin count=2 skip=36
# 8 bytes for tilemap MMR
$NULLDD of=scr_mmr.bin count=1 skip=2432 ibs=8
# 8 bytes for object MMR
$NULLDD of=obj_mmr.bin count=1 skip=2433 ibs=8
# Priority config
$NULLDD of=prio.bin count=1 skip=19471 ibs=1

jtsim -sysname aliens -nosnd -d NOMAIN -video 3 -zoom $OTHER