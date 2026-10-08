#!/bin/bash

# Video simulation

SCENE=
FNAME=
OTHER=

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1;;
        -f|--file)
            shift
            FNAME=$1;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

if [ -z "$FNAME" ]; then
    FNAME=$(basename $(pwd))
    FNAME=${FNAME^^}
    echo $FNAME
    if [ $FNAME = GAME ]; then
        echo "Cannot determine game name. Using dump.bin for scene data"
        FNAME=dump.bin
    else
        FNAME=${FNAME}.RAM
        echo "Using $FNAME as file name for scene data"
    fi
fi

if [ -z $SCENE ]; then
    echo "Generate scenes on MiST by saving the NVRAM"
    echo "And copying $FNAME from MiST's SD card to here"
    exit 0
fi

TMP=scenes/$SCENE/$FNAME
NULLDD="dd status=none if=$TMP"

# 16 kB Tilemap VRAM
$NULLDD of=scr1.bin    count=16
$NULLDD of=scr0.bin    count=16 skip=16
# 2 kB PAL
$NULLDD of=pal.bin     count=4 skip=32
# 1 kB Sprite LUT
$NULLDD of=obj.bin     count=2 skip=36
# 8 bytes for tilemap MMR
$NULLDD of=scr_mmr.bin count=1 skip=2432  bs=8
# 8 bytes for object MMR
$NULLDD of=obj_mmr.bin count=1 skip=2433  bs=8
# Priority config
$NULLDD of=prio.bin    count=1 skip=19471 bs=1
