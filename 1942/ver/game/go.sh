#!/bin/bash
MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

export GAME_ROM_PATH=../../../rom/JT1942.rom
export MEM_CHECK_TIME=66_000_000
# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh $MIST -d GAME_ROM_LEN=240128 \
     $* -sysname 1942 \
    -modules ../../../modules 
