#!/bin/bash

if (echo $PATH | grep modules/jtframe/bin -q); then
    echo ERROR: path variable already points to a modules/jtframe/bin folder
    echo source setprj.sh with a clean PATH
else
    export JTROOT=$(pwd)
    export JTFRAME=$JTROOT/modules/jtframe

    PATH=$PATH:$JTFRAME/bin:.
    #unalias jtcore
    alias jtcore="$JTFRAME/bin/jtcore"

    # derived variables
    CORES=$JTROOT/cores
    ROM=$JTROOT/rom
    MRA=$ROM/mra
    MODULES=$JTROOT/modules
    JT12=$MODULES/jt12
    JT51=$MODULES/jt51
fi
