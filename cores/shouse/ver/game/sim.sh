#!/bin/bash
# no-load data for mask BRAM
if [ -e sdram_bank2.bin ]; then
	dd if=sdram_bank2.bin of=mask.bin conv=swab count=256
fi

jtsim $*
