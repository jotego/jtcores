#!/bin/bash
git config --global --add safe.directory /jtcores
cd /jtcores
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe

source $JTFRAME/bin/setprj.sh
export PATH=$PATH:/usr/local/go/bin
if [ -e $CORES/$1/cfg/macros.def ]; then
    jtframe
    jtseed 3 $1 -mister --nodbg
fi
