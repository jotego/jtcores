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
export YM2203=1
export I8051=1
export MSM5205=1

# Generic simulation script from JTFRAME
jtsim $MIST -sysname tora \
    -d JTFRAME_SIM_ROMRQ_NOCHECK \
    -def ../../hdl/jtf1dream.def \
    -d FAST_LOAD \
    $*
