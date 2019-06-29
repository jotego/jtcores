#!/bin/bash

for i in ../../mist/*hex; do
    if [ ! -e $(basename $i) ]; then
        if [ -e "$i" ]; then ln -s $i; fi
    fi
done

MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

export GAME_ROM_PATH=../../../rom/JTCOMMANDO.rom
export MEM_CHECK_TIME=90_000_000

# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh $MIST -d GAME_ROM_LEN=887808 -sysname commando \
    -modules ../../../modules $*
