#!/bin/bash

MIST=-mist
VIDEO=0
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
    if [ "$k" = -video ]; then
        VIDEO=1
    fi
done

export MEM_CHECK_TIME=310_000_000
# 280ms to load the ROM ~17 frames
export CONVERT_OPTIONS="-resize 300%x300%"
# uncomment for fast load simulation
export YM2203=1
export MSM5205=1

# Generic simulation script from JTFRAME
# Note that rom.bin cannot be used directly
# You need to get sdram_bank?.hex dumps from
# a -load simulation
jtsim $MIST -sysname tora -d FAST_LOAD \
    -d JTFRAME_SIM_ROMRQ_NOCHECK \
    $*
