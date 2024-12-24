#!/bin/bash

SCENE=

# keep the file image orientation the same when flip is set:
# export CONVERT_OPTIONS="-flip -flop"

while [ $# -gt 0 ]; do
    case $1 in
        -s|-scene)
            shift
            OTHER="$OTHER -nosnd -d NOMAIN -d NOMCU -video 2 -zoom"
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
    jtutil drop1 -l < $SCENE/vram.bin > vram_hi.bin
    jtutil drop1    < $SCENE/vram.bin > vram_lo.bin
    jtutil drop1 -l < $SCENE/scrram.bin > scrram_hi.bin
    jtutil drop1    < $SCENE/scrram.bin > scrram_lo.bin
    jtutil drop1 -l < $SCENE/objram.bin > objram_hi.bin
    jtutil drop1    < $SCENE/objram.bin > objram_lo.bin
    cp $SCENE/scrpos.hex .
fi

jtsim -verilator $OTHER
