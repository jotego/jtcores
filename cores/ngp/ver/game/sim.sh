#!/bin/bash

while [ $# -gt 0 ]; do
    case $1 in
        -nvram)
            cp nvram nvram.bin
            OTHER="$OTHER -d NVRAM"
            ;;
        -cart)
            shift
            ln -sf "$1" cart.bin || exit $?
            ;;
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

function split {
    cat ${1}ram.bin | drop1    > ${1}_hi.bin
    cat ${1}ram.bin | drop1 -l > ${1}_lo.bin
}

if [ -n "$SCENE" ]; then
    dd if=$SCENE/vram.bin of=regsram.bin ibs=64 count=1
    dd if=$SCENE/vram.bin of=pal.bin ibs=1 count=25 skip=256
    dd if=$SCENE/vram.bin of=objram.bin  ibs=256 count=1 skip=8
    dd if=$SCENE/vram.bin of=scr1ram.bin count=4 skip=8
    dd if=$SCENE/vram.bin of=scr2ram.bin count=4 skip=12
    dd if=$SCENE/vram.bin of=chram.bin count=16 skip=16
    for i in obj ch scr1 scr2 regs; do split $i; done
    # rm -f objram.bin charam.bin
fi

jtsim $OTHER
