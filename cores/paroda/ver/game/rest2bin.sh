#!/bin/bash -e

if [[ ${1:-} == --delete ]]; then
    rm -f scr0.bin scr1.bin scrx.bin pal.bin pal_hi.bin pal_lo.bin \
          obj.bin obj_hi.bin obj_lo.bin pal_mmr.bin scr_mmr.bin \
          obj_mmr.bin other.bin
    exit 0
fi

FULLOBJ=
FSIZE=$(wc -c <"rest.bin")

if [[ $FSIZE -gt 0x70A0 ]]; then
	FULLOBJ="--fullobj"
fi

../game/dump_split.sh -f "rest.bin" $FULLOBJ
