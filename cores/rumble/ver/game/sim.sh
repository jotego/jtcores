#!/bin/bash

SYSNAME=rumble
HEXDUMP=-nohex
SIMULATOR=-verilator
SDRAM_SNAP=
DEF=

AUXTMP=/tmp/$RANDOM$RANDOM
jtmacros.awk target=mist mode=bash ../../hdl/jt${SYSNAME}.def|grep _START > $AUXTMP
source $AUXTMP

ln -sf $ROM/srumbler.rom rom.bin

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

jtsim_sdram $HEXDUMP  \
    -banks $BA1_START $BA2_START $BA3_START \
    -stop $PROM_START \
    -dumpbin 63s141.12a 0xcc000 0x100 \
    -dumpbin 63s141.13a 0xcc100 0x100 \
    -dumpbin 63s141.8j  0xcc200 0x100 \
    $SDRAM_SNAP || exit $?

jtsim -mist -sysname $SYSNAME $SIMULATOR \
	-videow 352 -videoh 240 \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $* || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
	eom frame_1.jpg 2> /dev/null
fi