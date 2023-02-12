#!/bin/bash
if [ $# != 2 ]; then
    echo "Usage: cpmame.sh game scene"
    exit 1
fi

mkdir -p $1

cp -v vram.bin $1/vram$2.bin || exit 1
cp -v obj.bin $1/obj$2.bin   || exit 1

MAMESNAP=~/.mame/snap/$1

if [ ! -d $MAMESNAP ]; then
    echo Warning: no MAME snapshot for $1
else
    # copy latest snap file from MAME
    LATEST=$(ls $MAMESNAP -t | head -n 1)
    cp -v $MAMESNAP/$LATEST $1/$2.png
fi

git add --force $1/{vram$2.bin,obj$2.bin} $1/{regs,prio,off}$2.hex $1/$2.png
