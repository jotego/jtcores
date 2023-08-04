#!/bin/bash

if [ ! -e nvram.bin ]; then
    cat <<EOF
This system requires a valid nvram.bin file to boot up properly
Use MAME's simpsons.12c.nv file for the "simpsons" set
EOF
    exit 0
fi

if [ -e SIMPSONS.RAM ]; then
    dd if=SIMPSONS.RAM of=scr0.bin count=16
    dd if=SIMPSONS.RAM of=scr1.bin count=16 skip=16
    dd if=SIMPSONS.RAM of=pal.bin count=8 skip=32
    dd if=SIMPSONS.RAM of=obj.bin count=8 skip=40
    drop1 -l < obj.bin > obj_lo.bin
    drop1    < obj.bin > obj_hi.bin
    # MMR
    dd if=SIMPSONS.RAM of=scr_mmr.bin bs=1 count=8 skip=$((48*512))
    dd if=SIMPSONS.RAM of=obj_mmr.bin bs=1 count=8 skip=$((48*512+8))
    dd if=SIMPSONS.RAM of=nvram.bin bs=1 count=128 skip=$((48*512+128))
fi

jtsim $*
