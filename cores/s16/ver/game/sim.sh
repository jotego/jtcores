#!/bin/bash

SYSNAME=s16
GAME=shinobi
SCENE=
OTHER=
HEXDUMP=-nohex
# SIMULATOR=-verilator
SDRAM_SNAP=

eval `jtframe cfgstr s16 --target=mist --output=bash`

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
	echo "Simulating scene $SCENE"

	if [ ! -e $GAME/char$SCENE.bin ]; then
	    echo Cannot open scene files
	    exit 1
	fi

	jtutil drop1    < $GAME/char${SCENE}.bin > char_hi.bin
	jtutil drop1 -l < $GAME/char${SCENE}.bin > char_lo.bin

	jtutil drop1    < $GAME/pal${SCENE}.bin > pal_hi.bin
	jtutil drop1 -l < $GAME/pal${SCENE}.bin > pal_lo.bin

	jtutil drop1    < $GAME/obj${SCENE}.bin > obj_hi.bin
	jtutil drop1 -l < $GAME/obj${SCENE}.bin > obj_lo.bin

    hexdump -v -e '/1 "%02X "' -s 0xe00 $GAME/char${SCENE}.bin > mmr.hex

	cp $GAME/scr${SCENE}.bin scr.bin
    OTHER="$OTHER -d NOMAIN -video -nosnd"
    if [[ ! "$*" =~ -time ]]; then
        OTHER="$OTHER -time 16"
    fi
    SDRAM_SNAP="-snap scr.bin 0 0x200000"
else
    rm -f char_*.bin pal_*.bin obj_*.bin scr.bin
fi

if which ncverilog 2&> /dev/null; then
    # Options for non-verilator simulation
    SIMULATOR=
    HEXDUMP=
fi

# Verilator does the job fast enough
# for iVerilog, jtsim_sdram is more convenient
if which jtsim_sdram 2&> /dev/null; then
    rm -f sdram_bank?.*
    jtsim_sdram $HEXDUMP -header 32 \
        -banks $JTFRAME_BA1_START $JTFRAME_BA2_START $JTFRAME_BA3_START \
        -stop $MCU_START \
        -dumpbin mcu.bin      $MCU_START     0x2000 \
        -dumpbin 317-5021.key $MAINKEY_START 0x2000 \
        -dumpbin fd1089.bin   $FD1089_START  0x0100 \
        $SDRAM_SNAP || exit $?

    jtsim_sdram -header 32 -dumpbin fd1094.bin 0x182000 8192
fi

jtsim -mist -sysname $SYSNAME $SIMULATOR \
        -d JTFRAME_SIM_ROMRQ_NOCHECK $OTHER || exit $?

if [[ ! -z "$SCENE" && -e frame_1.jpg ]]; then
	eom frame_1.jpg 2> /dev/null
fi