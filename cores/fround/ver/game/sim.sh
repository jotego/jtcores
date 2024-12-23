#!/bin/bash

OTHER=
SCENE=

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1
            OTHER="-d NOMAIN -d NOSOUND -video 3 -w"
            if [ ! -d scenes/$1 ]; then
                echo "Cannot open folder $SCENE"
                exit 1
            fi;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [ ! -z "$SCENE" ]; then
    dump2bin.sh scenes/$SCENE/FROUND.RAM
else
    rm -f {scr*,pal,obj*}.bin
fi

jtsim $OTHER -undef NOLUTFB

if [[ ! -z "SCENE" && -e frames/frame_00001.jpg ]]; then
    rm -f scenes/$SCENE/frame*.jpg
    cp frames/* scenes/$SCENE
fi
