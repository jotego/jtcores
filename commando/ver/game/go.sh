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
export MEM_CHECK_TIME=86_000_000
GAME_ROM_LEN=$(stat -c%s $GAME_ROM_PATH)

# create scroll RAM files with initial value for simulation
make

# Generic simulation script from JTFRAME
echo "Game ROM length: " $GAME_ROM_LEN
../../../modules/jtframe/bin/sim.sh $MIST -d GAME_ROM_LEN=$GAME_ROM_LEN\
    -sysname commando -modules ../../../modules -d SCANDOUBLER_DISABLE $*
