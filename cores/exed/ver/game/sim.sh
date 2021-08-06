#!/bin/bash

SYSNAME=exed
HEXDUMP=-nohex
SIMULATOR=-verilator
DEF=

AUXTMP=/tmp/$RANDOM$RANDOM
jtcfgstr -target=mist -output=bash -parse ../../hdl/jt${SYSNAME}.def |grep _START > $AUXTMP
source $AUXTMP

ln -sfr $ROM/exedexes.rom rom.bin

if which ncverilog >/dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

jtsim_sdram $HEXDUMP  \
    -stop $PROM_START || exit $?

jtsim -mist -sysname $SYSNAME $SIMULATOR \
	-videow 352 -videoh 240 \
    -d JTFRAME_SIM_ROMRQ_NOCHECK -d JTFRAME_DWNLD_PROM_ONLY $* || exit $?

# if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
# 	eom frame_1.jpg 2> /dev/null
# fi