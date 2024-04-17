#!/bin/bash

OTHER=
SCENE=

for i in $*; do
    case $i in
        -s)
            shift
            SCENE=$1
            OTHER="$OTHER -d NOMAIN -d NOSOUND -video 2q"
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
    cat $SCENE/pal.bin | jtutil drop1    > pal_lo.bin
    cat $SCENE/pal.bin | jtutil drop1 -l > pal_hi.bin
    cat $SCENE/oram.bin | jtutil drop1    > obj_lo.bin
    cat $SCENE/oram.bin | jtutil drop1 -l > obj_hi.bin
    dd if=$SCENE/vram.bin of=sdram_bank0.bin conv=notrunc seek=$((2176*2))
fi

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER
