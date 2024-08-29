#!/bin/bash

OTHER=
SCENE=
FNAME=
ALL=
TARGET=28833
EXCLUDE="-a --all"
ARGS=()

for arg in "$@"; do
    if [[ ! $EXCLUDE =~ $arg ]]; then
        ARGS+=("$arg")
    fi
done

while [ $# -gt 0 ]; do
    case $1 in
        -s|--scene)
            shift
            SCENE=$1
            if [ ! -d scenes/$1 ]; then
                echo "Cannot open folder $SCENE"
                exit 1
            fi;;
        -f|--file)
			shift
			FNAME=$1;;
		-a|--all)
			ALL=1;;
		-t|--target)
			shift
			TARGET=$1;;
        # --crc)
            # CRC=1;;
        # --batch) BATCH=1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

if [[ -z "$SCENE" && -z "$ALL" ]]; then
	exit 0
fi

if [ -z "$FNAME" ]; then
	FNAME=$(basename $(pwd))
	FNAME=${FNAME^^}.RAM
	if [ $FNAME = GAME ]; then
		echo "Cannot determine game name. Using dump.bin for scene data"
		FNAME=dump.bin
	else
		echo "Using $FNAME as file name for scene data"
	fi
fi

if [ "$ALL" = "1" ]; then
	for i in scenes/*; do
	    addzeros.sh -s $(basename $i) "${ARGS[@]}"
	done
fi

DIV=$((1+(16+16+8+8)*4))
OR_FILE="scenes/$SCENE/$FNAME"
ADD=$((TARGET -1 -$(stat --format=%s "$OR_FILE")))
if [ $ADD -gt 0 ]; then
	TMP=`mktemp`
	dd if="$OR_FILE" of="${SCENE}.bin" bs=128 count=$DIV  2> /dev/null
	dd if="$OR_FILE" of=$TMP           bs=128 skip=$DIV   2> /dev/null
    dd if=/dev/zero bs=1 count=$ADD >> "${SCENE}.bin"     2> /dev/null
	cat $TMP >> "${SCENE}.bin"
    dd if=/dev/zero bs=1 count=1    >> "${SCENE}.bin"     2> /dev/null
    cat "$OR_FILE" > "scenes/$SCENE/or_${FNAME}"; cat "${SCENE}.bin" > "$OR_FILE"
	rm -f $TMP "${SCENE}.bin"
else
	echo "File $SCENE/$FNAME already reaches/surpasses target size. Skipping"
	exit 0
fi

