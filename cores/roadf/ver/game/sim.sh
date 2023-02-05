#!/bin/bash

OTHER=
SCENE=

for i in $*; do
    case $i in
        -g)
            shift
            if [ ! -e $ROM/$1.rom ]; then
                echo Cannot find $ROM/$1.rom
                exit 1
            fi
            ln -sf $ROM/$1.rom rom.bin
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

if [ -n "$SCENE" ]; then
    cp -v $SCENE/vram_*.bin .
    if [ -e $SCENE/obj.bin ]; then
        cp $SCENE/obj.bin obj_lo.bin
        cp $SCENE/obj.bin obj_hi.bin
    fi
    # go run obj2sim.go $SCENE/obj.bin || exit $?
fi

jtsim $OTHER
