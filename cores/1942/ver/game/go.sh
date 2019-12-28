#!/bin/bash
MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

export GAME_ROM_PATH=../../../rom/JT1942.rom
export MEM_CHECK_TIME=68_000_000
export CONVERT_OPTIONS="-rotate -90 -resize 300%x300%"
#export CONVERT_OPTIONS="-resize 300%x300%"
export YM2149=1

# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh $MIST -d GAME_ROM_LEN=240128 -d VERTICAL_SCREEN \
     $* -sysname 1942 \
    -modules ../../../modules 
