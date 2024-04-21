#!/bin/bash

SCENE=
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

if [ -n "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo "Scene folder $SCENE not found"
        exit 1
    fi
    # only support for pal + objects
    cat $SCENE/pal0.bin | jtutil drop1 -l > pal0_hi.bin
    cat $SCENE/pal0.bin | jtutil drop1    > pal0_lo.bin
    cat $SCENE/pal1.bin | jtutil drop1    > pal1_lo.bin
    cat $SCENE/obj.bin  | jtutil drop1 -l > obj_hi.bin
    cat $SCENE/obj.bin  | jtutil drop1    > obj_lo.bin
    OTHER="$OTHER -d NOSOUND -d NOMAIN"
else
    rm -f char_*.bin pal_*.bin obj_*.bin scr.bin
fi

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER || exit $?
