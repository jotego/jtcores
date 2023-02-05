#!/bin/bash

OTHER=
SCENE=

for i in $*; do
    case $i in
        -s)
            shift
            SCENE=$1
            OTHER="$OTHER -d NOMAIN -d NOSND -video 2"
            if [ ! -d $SCENE ]; then
                echo Cannot find scene $SCENE
                exit 1
            fi
            ;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

if [ -n "$SCENE" ]; then
    dd if=$SCENE/vram.bin of=vram_lo.bin count=2
    dd if=$SCENE/vram.bin of=vram_hi.bin skip=2 count=2
    cp $SCENE/oram.bin .
fi

jtsim $OTHER
