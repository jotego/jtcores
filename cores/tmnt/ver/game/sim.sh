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

if [ ! -z "$SCENE" ]; then
    TMP=scenes/$SCENE/TMNT.RAM
    dd if=$TMP of=scr1.bin count=16         2> /dev/null
    dd if=$TMP of=scr0.bin count=16 skip=16 2> /dev/null
    dd if=$TMP of=pal.bin count=8 skip=32   2> /dev/null
    dd if=$TMP of=obj.bin count=2 skip=40   2> /dev/null
    drop1 -l < obj.bin > obj_lo.bin
    drop1    < obj.bin > obj_hi.bin
    # MMR
    dd if=$TMP of=pal_mmr.bin bs=8 count=2 skip=$((42*512/8))   2> /dev/null
    dd if=$TMP of=scr_mmr.bin bs=8 count=1 skip=$((42*512/8+1)) 2> /dev/null
    dd if=$TMP of=obj_mmr.bin bs=8 count=1 skip=$((42*512/8+2)) 2> /dev/null
    dd if=$TMP of=prio.bin    bs=8 count=1 skip=$((42*512/8+3)) 2> /dev/null
else
    rm -f {scr?,pal,obj_??,???_mmr,prio}.bin
fi

jtsim $OTHER

if [[ ! -z "SCENE" && -e frames/frame_00001.jpg ]]; then
    rm -f scenes/$SCENE/frame*.jpg
    cp frames/* scenes/$SCENE
fi
