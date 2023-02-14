#!/bin/bash

MIST=-mist
TOKIO=
ARGS=

ln -srf $ROM/bublbobl.rom rom.bin

for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
    if [ "$k" = -tokio ]; then
        echo "TOKIO selected"
        TOKIO="-d TOKIO"
        ln -srf $ROM/tokiob.rom rom.bin
        continue
    fi
    ARGS="$ARGS $k"
done
ARGS="$ARGS $TOKIO"

# Mare SDRAM file
bin2hex < rom.bin > sdram.hex

# Find PROM file
if [ ! -e a71-25.41 ]; then
    zipfile=$(locate bublbobl.zip | head -n 1)
    if [ -z "$zipfile" ]; then
        echo "ERROR: cannot locate bublbobl.zip. Needed to extract a71-25.41."
        exit 1
    fi
    unzip -o $zipfile a71-25.41 || exit $?
fi

# export YM2203=1
# export YM3526=1
# export Z80=1

# if [ -z "$TOKIO" ]; then
#     export M6801=1
# fi

jtsim $MIST \
    -sysname bubl -d SCANDOUBLER_DISABLE=1 \
    -def ../../hdl/jtbubl.def \
    -d VIDEO_START=1 -d JTFRAME_SIM_ROMRQ_NOCHECK \
    -d JTFRAME_SIM_DIPS="16'hfffe" \
    $ARGS
