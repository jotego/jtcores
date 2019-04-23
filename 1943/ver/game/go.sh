#!/bin/bash

for i in ../../mist/*hex; do
    if [ ! -e $(basename $i) ]; then
        ln -s $i
    fi
done

../../../modules/jtframe/bin/sim.sh -mist $* -sysname 1943 \
    -modules ../../../modules 
