#!/bin/bash

if (echo $PATH | grep modules/jtframe/bin -q); then
    echo ERROR: path variable already points to a modules/jtframe/bin folder
    echo source setprj.sh with a clean PATH
else
    export JTROOT=$(pwd)
    export JTFRAME=$JTROOT/modules/jtframe

    source $JTFRAME/bin/setprj.sh $*
fi
