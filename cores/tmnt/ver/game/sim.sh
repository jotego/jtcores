#!/bin/bash

OTHER=
SCENE=

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1
            OTHER="-d NOMAIN -d NOSOUND -video 2 -w"
            if [ ! -d scenes/$1 ]; then
                echo "Cannot open folder $SCENE"
                exit 1
            fi;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

$CORES/riders/ver/game/dump_split.sh --scene "$SCENE"

jtsim $OTHER

if [[ ! -z "SCENE" && -e frames/frame_00001.jpg ]]; then
    rm -f scenes/$SCENE/frame*.jpg
    cp frames/* scenes/$SCENE
fi
