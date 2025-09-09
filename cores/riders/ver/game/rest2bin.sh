#!/bin/bash -e

PSAC=
FSIZE=$(wc -c <"rest.bin")

if [[ $FSIZE -gt 0x8821 ]]; then
	PSAC="--psac_mmr"

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
