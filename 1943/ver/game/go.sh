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

# Generic simulation script from JTFRAME
../../../modules/jtframe/bin/sim.sh -mist $* -sysname 1943 \
    -modules ../../../modules 
