#!/bin/bash

SCENE=
OTHER=
HEXDUMP=-nohex
SDRAM_SNAP=

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

# scene won't work with -load because
# it requires to overwrite SDRAM bank0
if [ -n "$SCENE" ]; then
    SNAP=scenes/$SCENE.snap
    if [ ! -e "$SNAP" ]; then
        echo "Scene snapshot $SNAP not found"
        exit 1
    fi
    SWAB=conv=swab
    dd if=$SNAP of=sdram_bank0.bin $SWAB
    dd if=$SNAP of=pal.bin bs=1024 skip=58 count=2
    dd if=$SNAP of=obj.bin bs=1024 skip=60 count=2
    dd if=$SNAP of=ba0.bin bs=16 skip=$(printf "%d" 0xf80) count=1
    dd if=$SNAP of=ba1.bin bs=16 skip=$(printf "%d" 0xf81) count=1
    dd if=$SNAP of=ba2.bin bs=16 skip=$(printf "%d" 0xf82) count=1
    dd if=$SNAP of=prisel.bin bs=1 skip=$(printf "%d" 0xf830) count=1
    # only support for pal + objects
    cat pal.bin | jtutil drop1    > pal_hi.bin
    cat pal.bin | jtutil drop1 -l > pal_lo.bin
    cat obj.bin | jtutil drop1    > obj_hi.bin
    cat obj.bin | jtutil drop1 -l > obj_lo.bin

    OTHER="$OTHER -d NOSOUND -d NOMAIN -w -video 2 -zoom"
else
    rm -f char_*.bin pal_*.bin obj_*.bin scr.bin
fi

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER || exit $?
