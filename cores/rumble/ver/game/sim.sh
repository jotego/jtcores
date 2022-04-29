#!/bin/bash

SYSNAME=rumble
HEXDUMP=-nohex
#SIMULATOR=-verilator
SDRAM_SNAP=
DEF=
OTHER=
SCENE=
SKIP="-d SKIPOBJ32"

eval `jtcfgstr -output bash -core ${SYSNAME} | grep _START `

if [ ! -e rom.bin ]; then ln -s $ROM/srumbler.rom rom.bin; fi

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

while [ $# -gt 0 ]; do
    case $1 in
        -s|-scene)
            shift
            SCENE=$1
            OTHER="-d NOSOUND -d NOMAIN -video 2"
            ;;
        -h|-help)
            echo "Rumble simulation specific commands"
            echo "   -s|-scene  selects simulation scene. Turns off MAIN/SOUND simulation"
            echo -e " ----------------------\n"
            jtsim -sysname rumble -help
            exit 0;;
        -load)
            SKIP=
            OTHER="$OTHER $1";;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [ -n "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo Cannot find scene folder "$SCENE"
        exit 1
    fi
    cat $SCENE/char.bin | drop1    >  char_lo.bin
    cat $SCENE/char.bin | drop1 -l >  char_hi.bin
    cat $SCENE/scr.bin | drop1 -l  > scr1_lo.bin
    cat $SCENE/scr.bin | drop1     > scr1_hi.bin
fi

jtsim -mist -sysname $SYSNAME $SIMULATOR \
	-videow 352 -videoh 240 \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER $SKIP \
    || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
	eom frame_1.jpg 2> /dev/null
fi