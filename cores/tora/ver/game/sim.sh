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
    cp $SCENE/* .
    source scrpos.sh
    jtsim -nosnd -d NOMAIN -d NOMCU -video 5 \
        -d JTCHAR_UPPER_SIMFILE=',.simfile({"char_upper.bin"})' \
        -d JTCHAR_LOWER_SIMFILE=',.simfile({"char_lower.bin"})' \
        -d SIM_SCR_HPOS=16\'h$SCRHPOS \
        -d SIM_SCR_VPOS=16\'h$SCRVPOS \
        -d SIM_SCR_BANK=1\'b$SCRBANK \
        -d VIDEO_START=1 \
        -deep $OTHER
else
    jtsim $OTHER
fi
