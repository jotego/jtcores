#!/bin/bash

if [ -z "$1" ]; then
    echo "Call it with the name of the new scene folder"
fi

if [ -e /m/MIST/HYPERSPT.RAM ]; then
    cp -v /m/MIST/HYPERSPT.RAM .
fi

dd if=HYPERSPT.RAM of=vram_lo.bin count=4
dd if=HYPERSPT.RAM of=vram_hi.bin count=4 skip=4
dd if=HYPERSPT.RAM of=obj_lo.bin count=2 skip=8
dd if=HYPERSPT.RAM of=obj_hi.bin count=2 skip=10

mkdir -p $1
mv vram*.bin obj*.bin $1