#!/bin/bash

OTHER=
SCENE=
BATCH=
CRC=
if [ $(basename $(pwd)) = ssriders ]; then SSRIDERS=1; else SSRIDERS=;fi
#if [ $(basename $(pwd)) = vendetta ]; then VENDETTA=1; else VENDETTA=;fi

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1
            OTHER="-d NOMAIN -d NOSOUND -zoom -video 2 -w"
            if [ ! -d scenes/$1 ]; then
                echo "Cannot open folder $SCENE"
                exit 1
            fi;;
        --crc)
            CRC=1;;
        --batch) BATCH=1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [[ ! -e nvram.bin && -z "$SSRIDERS" && -z "$SCENE" ]]; then
    cat <<EOF
This system requires a valid nvram.bin file to boot up properly
Use MAME's simpsons.12c.nv file for the "simpsons" set
EOF
    exit 0
fi

../game/dump_split.sh --scene "$SCENE" --nvram

jtsim $OTHER

if [[ ! -z "SCENE" && -e frames/frame_00001.jpg ]]; then
    rm -f scenes/$SCENE/frame*.jpg
    cp `ls frames/*jpg|tail -n 1` scenes/$SCENE/$SCENE.jpg
    if which eom > /dev/null; then
        if [[ ! -z "$SCENE" && -e frames/frame_00001.jpg && -z "$BATCH" ]]; then
            eom `ls frames/frame_*.jpg | tail -n 1` &
        fi
    fi
    if [[ ! -e scenes/$SCENE/$SCENE.crc || $CRC = 1 ]]; then
        tail -n 1 frames/frames.crc > scenes/$SCENE/$SCENE.crc
    else
        if ! diff -q <(tail -n 1 frames/frames.crc) scenes/$SCENE/$SCENE.crc > /dev/null; then
            echo "WARNING: the image CRC has changed for scene $SCENE"
            exit 1
        fi
    fi
fi
