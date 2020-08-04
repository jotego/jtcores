#!/bin/bash

MIST=-mist
VIDEO=0

for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
    if [ "$k" = -video ]; then
        VIDEO=1
    fi
done


export GAME_ROM_PATH=../../../rom/trojan.rom
export MEM_CHECK_TIME=106_000_000
export CONVERT_OPTIONS="-resize 300%x300%"
export YM2203=1
export Z80=1

if [ ! -e $GAME_ROM_PATH ]; then
    echo Missing file $GAME_ROM_PATH
    exit 1
fi

# The sdram.hex file cannot be made with bin2hex
# because of the prom_we loader. You need to run goload.sh
# to get sdram.hex

# Generic simulation script from JTFRAME
$JTFRAME/bin/sim.sh $MIST \
    -sysname trojan \
    -def ../../hdl/jttrojan.def \
    -videow 256 -videoh 240 \
    -d BUTTONS=2 \
    -d COLORW=4  \
    $*
