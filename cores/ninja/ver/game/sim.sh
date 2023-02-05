#!/bin/bash

SYSNAME=ninja
GAME=baddudes
SCENE=
OTHER=
HEXDUMP=-nohex
SIMULATOR=-verilator
SDRAM_SNAP=

eval `jtcfgstr -output=bash -core ninja | grep _START`

while [ $# -gt 0 ]; do
    case $1 in
        -g)
            shift
            GAME=$1
            if [ ! -e $ROM/$GAME.rom ]; then
                echo "Cannot find ROM file $ROM/$GAME.rom"
                exit 1
            fi
            ;;
        -s|-scene)
            shift
            SCENE=$1;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

ln -sf $ROM/$GAME.rom rom.bin

if [ ! -z "$SCENE" ]; then
    echo "Scene simulation not supported"
    exit 1
else
    export YM2203=1
    export YM3812=1
    export MC6502=1
    export I8051=1
    export MSM6295=1
    rm -f char_*.bin pal_*.bin obj_*.bin scr.bin
fi

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

# Cannot use jtsim_sdram because of gfx
# address changes during load
# rm -f sdram_bank?.*
# jtsim_sdram $HEXDUMP  \
#     -banks $BA1_START $BA2_START $BA3_START \
#     -stop $MCU_START \
#     $SDRAM_SNAP || exit $?


jtsim -mist -sysname $SYSNAME $SIMULATOR \
    -videow 256 -videoh 240 -d JTFRAME_DWNLD_PROM_ONLY \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
    eom frame_1.jpg 2> /dev/null
fi