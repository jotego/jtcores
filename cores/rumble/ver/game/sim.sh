#!/bin/bash

SYSNAME=rumble
HEXDUMP=-nohex
SIMULATOR=-verilator
SDRAM_SNAP=
DEF=
OTHER=
SCENE=

AUXTMP=/tmp/$RANDOM$RANDOM
jtcfgstr -output bash -def ../../hdl/jt${SYSNAME}.def|grep _START > $AUXTMP
source $AUXTMP

ln -sf $ROM/srumbler.rom rom.bin

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

while [ $# -gt 0 ]; do
    case $1 in
        -s|-scene)
            shift
            SCENE=$1;;
        -h|-help)
            echo "Rumble simulation specific commands"
            echo "   -s|-scene  selects simulation scene. Turns off MAIN/SOUND simulation"
            echo -e " ----------------------\n"
            jtsim -sysname rumble -help
            exit 0;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

jtsim_sdram $HEXDUMP  \
    -banks $BA1_START $BA2_START $BA3_START \
    -stop $PROM_START \
    -dumpbin 63s141.12a 0xcc000 0x100 \
    -dumpbin 63s141.13a 0xcc100 0x100 \
    -dumpbin 63s141.8j  0xcc200 0x100 \
    $SDRAM_SNAP || exit $?

if [ -n "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo Cannot find scene folder "$SCENE"
        exit 1
    fi
    dd if=$SCENE/char.bin of=char_lo.bin count=4
    dd if=$SCENE/char.bin of=char_hi.bin seek=4 count=4
    dd if=$SCENE/scr.bin of=scr_lo.bin count=8
    dd if=$SCENE/scr.bin of=scr_hi.bin seek=8 count=8
fi

exit 0

jtsim -mist -sysname $SYSNAME $SIMULATOR \
	-videow 352 -videoh 240 \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER \
    || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
	eom frame_1.jpg 2> /dev/null
fi