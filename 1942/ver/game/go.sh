#!/bin/bash
MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done


# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh $MIST $* -sysname 1942 \
    -modules ../../../modules 
