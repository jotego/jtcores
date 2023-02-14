#!/bin/bash

# Use cpsnap.sh to copy MAME scenes to a new folder

ARG=
SCENE=

touch seta_cfg.hex

while [ $# -gt 0 ]; do
    case $1 in
        -s) shift
            SCENE=$1
            ARG="$ARG -d NOMAIN -nosnd -video 2"
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


jtsim -sysname kiwi -d JTFRAME_SIM_ROMRQ_NOCHECK $ARG
