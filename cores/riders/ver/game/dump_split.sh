#!/bin/bash -e

SCENE=
FNAME=
NVRAM=0
FULLRAM=0
DUALPAL=0
SKIP=0

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
		-x|--fullram)
			FULLRAM=1;;
		-p|--pal2)
			DUALPAL=1;;
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

dd if=$TMP      of=scr1.bin    count=16 skip=$SKIP      2> /dev/null; SKIP=$((SKIP +16))   # 8kB
dd if=$TMP      of=scr0.bin    count=16 skip=$SKIP      2> /dev/null; SKIP=$((SKIP +16))   # 8kB
if [ $FULLRAM = 1 ]; then
	dd if=$TMP  of=scrx.bin    count=16 skip=$SKIP      2> /dev/null; SKIP=$((SKIP +16))   # 8kB
fi
dd if=$TMP      of=pal.bin     count=8  skip=$SKIP      2> /dev/null; SKIP=$((SKIP +8 ))   # 4kB
dd if=$TMP      of=obj.bin     count=16 skip=$SKIP      2> /dev/null; SKIP=$((SKIP +16))   # 8kB
dd if=/dev/zero of=obj.bin     count=16 conv=notrunc oflag=append 2> /dev/null; SKIP=$((SKIP*512/8)) # 8kB blank
# MMR
dd if=$TMP of=pal_mmr.bin bs=8 count=2  skip=$SKIP      2> /dev/null; SKIP=$((SKIP +2))
dd if=$TMP of=scr_mmr.bin bs=8 count=1  skip=$SKIP      2> /dev/null; SKIP=$((SKIP +1))
dd if=$TMP of=obj_mmr.bin bs=8 count=1  skip=$SKIP      2> /dev/null; SKIP=$(((SKIP+1)*8))
dd if=$TMP of=other.bin   bs=1 count=1  skip=$SKIP      2> /dev/null
# convert to dual 8-bit dumps
if [ $DUALPAL=1 ]; then
	jtutil drop1 -l < pal.bin > pal_lo.bin
	jtutil drop1    < pal.bin > pal_hi.bin
fi
jtutil drop1 -l < obj.bin > obj_lo.bin
jtutil drop1    < obj.bin > obj_hi.bin

if [ $NVRAM = 1 ]; then rm -f $TMP; fi
