#!/bin/bash

OTHER=
SCENE=

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
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [ -n "$SCENE" ]; then
    if [ ! -d "$SCENE" ]; then
        echo Cannot find scene folder "$SCENE"
        exit 1
    fi
    cat $SCENE/char.bin | jtutil drop1    >  char_lo.bin
    cat $SCENE/char.bin | jtutil drop1 -l >  char_hi.bin
    cat $SCENE/scr.bin | jtutil drop1 -l  > scr1_lo.bin
    cat $SCENE/scr.bin | jtutil drop1     > scr1_hi.bin
fi

jtsim $*