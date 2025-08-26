#!/bin/bash -e

PSAC=
FSIZE=$(wc -c <"rest.bin")

if [[ $FSIZE -gt 0x90A1 ]]; then
	PSAC="--psac_mmr"

	dd if=sdram_bank3.bin of=AB.bin skip=3584 count=1024 bs=1024
	dd if=sdram_bank3.bin of=CC.bin skip=4608 count=256  bs=1024

	jtutil drop1 -l  < "AB.bin" >  "A.bin"
	jtutil drop1     < "AB.bin" >  "B.bin"
	jtutil drop1     < "CC.bin" >  "C.bin"

	python ../glfgreat/tilemap_blocks.py
fi

../game/dump_split.sh -f "rest.bin" --fullobj $PSAC
