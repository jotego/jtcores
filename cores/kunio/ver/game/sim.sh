#!/bin/bash

OTHER=
SCENE=
eval `$JTCFGSTR -core kunio -output bash`

while [ $# -gt 0 ]; do
    case "$1" in
        -s)
            shift
            SCENE=$1;;
        *) OTHER="$OTHER $1"
    esac
    shift
done

if [ -n "$SCENE" ]; then
    OTHER="$OTHER -d NOMAIN -nosnd -video 1"
    if [ ! -d $SCENE ]; then
        echo "Error: scene folder $SCENE does not exist"
        exit 1
    fi
    dd if=$SCENE/char.bin skip=12 count=2 of=aux_lo.bin
    dd if=$SCENE/char.bin skip=14 count=2 of=aux_hi.bin
    rm -f char_{lo,hi}.bin
    for i in 0 1 2 3; do
        cat aux_lo.bin >> char_lo.bin
        cat aux_hi.bin >> char_hi.bin
    done
    dd if=$SCENE/scr.bin of=scr_lo.bin count=2
    dd if=$SCENE/scr.bin of=scr_hi.bin count=2 skip=2
    dd if=$SCENE/obj.bin of=obj.bin count=2
    cp $SCENE/pal.bin .
fi

if [ ! -e rom.bin ]; then
    ln -sr $ROM/renegdeb.rom rom.bin || exit $?
fi

$JTFRAME/bin/jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER
