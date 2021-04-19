#!/bin/bash

for i in ../../mist/*hex; do
    if [ ! -e $(basename $i) ]; then
        ln -s $i
    fi
done

if [ ! -e ../../../rom/1943/bm05.4k.lsb ]; then
    # Prepare separated ROM files for sound CPU
    if ! dd if=../../../rom/1943/bm05.4k of=../../../rom/1943/bm05.4k.lsb count=16K; then
        exit 1
    fi
    if ! dd if=../../../rom/1943/bm05.4k of=../../../rom/1943/bm05.4k.msb count=16K skip=16K; then
        exit 1
    fi
fi

MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

export GAME_ROM_PATH=../../../rom/JT1943.rom
export MEM_CHECK_TIME=250_000_000
export CONVERT_OPTIONS="-rotate -90 -resize 300%x300%"
export YM2203=1

# Generic simulation script from JTFRAME
jtsim $MIST -d GAME_ROM_LEN=$GAME_ROM_LEN -sysname 1943 -d VERTICAL_SCREEN \
    -d JTFRAME_SIM_ROMRQ_NOCHECK \
    -modules ../../../modules $*
