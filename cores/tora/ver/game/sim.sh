#!/bin/bash

SCENE=
OTHER=

while [ $# -gt 0 ]; do
    case "$1" in
        -s) shift; SCENE=$1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [ ! -z "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo "Scene folder $SCENE does not exist"
        exit 1
    fi
    cp $SCENE/*.{hex,bin} .
    source $SCENE/scrpos.sh
    jtsim -nosnd -d NOMAIN -d NOMCU -video 3 \
        -d JTCHAR_UPPER_SIMFILE=',.simfile({"char_hi.bin"})' \
        -d JTCHAR_LOWER_SIMFILE=',.simfile({"char_lo.bin"})' \
        -d SIM_SCR1_HPOS=16\'h$SIM_SCR1_HPOS \
        -d SIM_SCR1_VPOS=16\'h$SIM_SCR1_VPOS \
        -d SIM_SCR_BANK=1\'b$SIM_SCR_BANK \
        -d VIDEO_START=1 \
        -deep $OTHER
else
    jtsim $OTHER
fi
