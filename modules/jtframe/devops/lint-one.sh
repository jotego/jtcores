#!/bin/bash

CORE=$1

eval `jtframe cfgstr $CORE --output bash --target mister`

if [[ ! -e $CORES/$CORE/cfg/macros.def || -e $CORES/$CORE/cfg/skip || -v JTFRAME_SKIP ]]; then
    echo "Skipping $CORE"
    exit 0
fi

cd $CORES/$CORE
mkdir -p ver/game
cd ver/game

if [ ! -e rom.bin ]; then
    # dummy ROM
    dd if=/dev/zero of=rom.bin count=1 2> /dev/null
    DELROM=
fi

jtsim -lint

if [ -v DELROM ]; then
    rm -f rom.bin
fi
