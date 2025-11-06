#!/bin/bash -e

FULLOBJ=
FSIZE=$(wc -c <"rest.bin")

if [[ $FSIZE -gt 0x70A0 ]]; then
	FULLOBJ="--fullobj"
fi

../game/dump_split.sh -f "rest.bin" $FULLOBJ
