#!/bin/bash

EXTRA=
SCENE=

function parse_args {
    while [ $# -gt 0 ]; do
        case $1 in
            -s|-scene) shift; SCENE=$1;;
        esac
        shift
    done
}

parse_args $*

# Core dump from MiST
if [ ! -z "$SCENE" ]; then
    DUMP=$SCENE/dump.nvm
    if [ ! -e $DUMP ]; then
        echo "Cannot open $DUMP"
        echo "Generate it using MiSTer"
        exit 1
    fi
    dd if=$DUMP of=aux.bin count=16
    jtutil drop1 -l < aux.bin > pal_lo.bin
    jtutil drop1    < aux.bin > pal_hi.bin
    dd if=$DUMP of=aux.bin count=16 skip=16
    jtutil drop1 -l < aux.bin > roadram_lo.bin
    jtutil drop1    < aux.bin > roadram_hi.bin
    dd if=$DUMP of=obj.bin count=8 skip=32
    jtutil drop1 -l < aux.bin > obj_lo.bin
    jtutil drop1    < aux.bin > obj_hi.bin
    rm -f aux.bin
    EXTRA="-d NOMAIN -d NOSOUND -d NOMCU"
fi

# Fast load
# rm -f sdram_bank*
# dd if=rom.bin of=sdram_bank0.bin ibs=16 skip=1 conv=swab
# $JTFRAME/bin/rom2sdram.sh $SYSNAME --header 16 --swab || exit $?

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $EXTRA $* || exit $?
