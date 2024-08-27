#!/bin/bash -e

SCENE=
FNAME=
NVRAM=0

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1;;
        -f|--file)
			shift
			FNAME=$1;;
		-v|--nvram)
			NVRAM=1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [ -z "$SCENE" ]; then
	rm -f {scr?,pal,obj_??,???_mmr}.bin
	exit 0
fi

if [ -z "$FNAME" ]; then
	FNAME=$(basename $(pwd))
	FNAME=${FNAME^^}
	if [ $FNAME = GAME ]; then
		echo "Cannot determine game name. Using dump.bin for scene data"
		FNAME=dump.bin
	else
		FNAME=${FNAME}.RAM
		echo "Using $FNAME as file name for scene data"
	fi
fi

# The first 128 bytes are NVRAM
if [ $NVRAM = 1 ]; then
	TMP=`mktemp`
	dd if=scenes/$SCENE/$FNAME of=nvram.bin bs=128 count=1 2> /dev/null
	dd if=scenes/$SCENE/$FNAME of=$TMP      bs=128 skip=1  2> /dev/null
else
	TMP=scenes/$SCENE/$FNAME
fi
dd if=$TMP      of=scr1.bin count=16                           2> /dev/null # 8kB
dd if=$TMP      of=scr0.bin count=16 skip=16                   2> /dev/null # 8kB
dd if=$TMP      of=scrx.bin count=16 skip=32                   2> /dev/null # 8kB
dd if=$TMP      of=pal.bin  count=8  skip=48                   2> /dev/null # 4kB
dd if=$TMP      of=obj.bin  count=16 skip=56                   2> /dev/null # 8kB
dd if=/dev/zero of=obj.bin  count=16 conv=notrunc oflag=append 2> /dev/null # 8kB blank
# MMR
dd if=$TMP of=pal_mmr.bin bs=8 count=2 skip=$((72*512/8))   2> /dev/null
dd if=$TMP of=scr_mmr.bin bs=8 count=1 skip=$((72*512/8+2)) 2> /dev/null
dd if=$TMP of=obj_mmr.bin bs=8 count=1 skip=$((72*512/8+3)) 2> /dev/null
dd if=$TMP of=other.bin   bs=1 count=1 skip=$((72*512+4*8)) 2> /dev/null
# convert to dual 8-bit dumps
jtutil drop1 -l < pal.bin > pal_lo.bin
jtutil drop1    < pal.bin > pal_hi.bin
jtutil drop1 -l < obj.bin > obj_lo.bin
jtutil drop1    < obj.bin > obj_hi.bin

if [ $NVRAM = 1 ]; then rm -f $TMP; fi
