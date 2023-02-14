#!/bin/bash

# The MCU gets out of reset at frame 19

# Use cpsnap.sh to copy MAME scenes to a new folder

ARG=
SCENE=

touch seta_cfg.hex

while [ $# -gt 0 ]; do
    case $1 in
        -s) shift
            SCENE=$1
            ARG="$ARG -d NOMAIN -d NOMCU -nosnd -video 2"
            ;;
        *) ARG="$ARG $1";;
    esac
    shift
done

if [ ! -z "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo "Requested scene $SCENE cannot be found"
        exit 1
    fi
    cp $SCENE/* .
fi


if [ ! -e rom.bin ]; then ln -sf $ROM/extrmatn.rom rom.bin; fi

jtsim -sysname kiwi -d JTFRAME_SIM_ROMRQ_NOCHECK $ARG
