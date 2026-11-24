#!/bin/bash -e

if [[ ${1:-} == --delete ]]; then
    rm -f scr0.bin scr1.bin scrx.bin line.bin line_hi.bin line_lo.bin \
          pal.bin pal_hi.bin pal_lo.bin \
          obj.bin obj_hi.bin obj_lo.bin psac.bin pal_mmr.bin scr_mmr.bin \
          obj_mmr.bin other.bin AB.bin CC.bin A.bin B.bin C.bin \
          t2x2.bin t2x2_hi.bin t2x2_lo.bin tilemap_2x2.hex
    # dump2bin.sh removes nvram.bin first; a local seed supports boot tests.
    if [[ -f nvram.seed ]]; then cp nvram.seed nvram.bin; fi
    exit 0
fi

PSAC=
FSIZE=$(wc -c <"rest.bin")

if [[ $FSIZE -gt 0x8821 ]]; then
	PSAC="--psac_mmr"

	jtutil sdram
	dd if=sdram_bank3.bin of=AB.bin skip=3584 count=1024 bs=1024
	dd if=sdram_bank3.bin of=CC.bin skip=4608 count=256  bs=1024

	jtutil drop1 -l  < "AB.bin" >  "A.bin"
	jtutil drop1     < "AB.bin" >  "B.bin"
	jtutil drop1     < "CC.bin" >  "C.bin"

	python ../glfgreat/tilemap_blocks.py

	cut -c2-5 tilemap_2x2.hex | xxd -r -p > t2x2.bin
	jtutil drop1 -l  < "t2x2.bin" >  "t2x2_hi.bin"
	jtutil drop1     < "t2x2.bin" >  "t2x2_lo.bin"
fi

../game/dump_split.sh -f "rest.bin" --fullobj $PSAC
