#!/bin/bash

OTHER=
SCENE=
if [ $(basename $(pwd)) = parodius ]; then PARODIUS=1; else PARODIUS=;fi

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

if [[ ! -e nvram.bin && -z "$PARODIUS" && -z "$SCENE" ]]; then
    cat <<EOF
This system requires a valid nvram.bin file to boot up properly
Use MAME's simpsons.12c.nv file for the "simpsons" set
EOF
    exit 0
fi

if [ ! -z "$SCENE" ]; then
    TMP=`mktemp`
    FNAME=SIMPSONS
    if [ -n "$PARODIUS" ]; then FNAME=PARODIUS; fi
    # The first 128 bytes are NVRAM
    dd if=scenes/$SCENE/${FNAME}.RAM of=nvram.bin bs=128 count=1 2> /dev/null
    dd if=scenes/$SCENE/${FNAME}.RAM of=$TMP bs=128 skip=1 2> /dev/null
    dd if=$TMP of=scr1.bin count=16         2> /dev/null
    dd if=$TMP of=scr0.bin count=16 skip=16 2> /dev/null
    dd if=$TMP of=pal.bin count=8 skip=32   2> /dev/null
    dd if=$TMP of=obj.bin count=8 skip=40   2> /dev/null
    dd if=/dev/zero of=obj.bin conv=notrunc oflag=append count=8 2> /dev/null
    drop1 -l < obj.bin > obj_lo.bin
    drop1    < obj.bin > obj_hi.bin
    # MMR
    dd if=$TMP of=pal_mmr.bin bs=8 count=2 skip=$((48*512/8))   2> /dev/null
    dd if=$TMP of=scr_mmr.bin bs=8 count=1 skip=$((48*512/8+2)) 2> /dev/null
    dd if=$TMP of=obj_mmr.bin bs=8 count=1 skip=$((48*512/8+3)) 2> /dev/null
    rm -f $TMP
else
    rm -f {scr?,pal,obj_??,???_mmr}.bin
fi

jtsim $OTHER

if [[ ! -z "SCENE" && -e frames/frame_00001.jpg ]]; then
    rm -f scenes/$SCENE/frame*.jpg
    cp frames/* scenes/$SCENE
fi
