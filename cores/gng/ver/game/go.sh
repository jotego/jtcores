#!/bin/bash

for i in ../../mist/*hex; do
    if [ ! -e $(basename "$i") ]; then
        if [ -e "$i" ]; then ln -s "$i"; fi
    fi
done

MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=-mister
    fi
done

# Create default palette files
if [[ ! -e rg_ram.hex || ! -e b_ram.hex ]]; then
    cnt=0;
    while [ $cnt != 256 ]; do
        echo FF >> rg_ram.hex
        echo  0 >> b_ram.hex
        cnt=$((cnt+1))
    done
fi

export GAME_ROM_PATH=../../../rom/JTGNG.rom
export MEM_CHECK_TIME=90_000_000
export CONVERT_OPTIONS="-resize 300%x300%"
export YM2203=1

echo convert $CONVERT_OPTIONS -size 256x240 \
        -depth 8 RGBA:video.raw video.jpg > raw2jpg.sh
chmod +x raw2jpg.sh

# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh $MIST -d GAME_ROM_LEN=$(stat -c%s $GAME_ROM_PATH) -sysname gng \
    -modules ../../../modules $*