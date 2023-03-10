#!/bin/bash

EXTRA=

if [ -e obj.bin ]; then
    drop1    < obj.bin >  obj_hi.bin
    drop1    < obj.bin >> obj_hi.bin
    drop1 -l < obj.bin >  obj_lo.bin
    drop1 -l < obj.bin >> obj_lo.bin
fi

if [ -e roadram.bin ]; then
    drop1    < roadram.bin > roadram_lo.bin
    drop1 -l < roadram.bin > roadram_hi.bin
    EXTRA="$EXTRA -d SIM_ROAD_CTRL"
fi

# Core dump from MiST
if [ -e OUTRUN.RAM ]; then
    dd if=OUTRUN.RAM of=pal.bin count=16
    drop1 -l < pal.bin > pal_lo.bin
    drop1    < pal.bin > pal_hi.bin
    dd if=OUTRUN.RAM of=roadram.bin count=8 skip=16
    drop1 -l < pal.bin > roadram_lo.bin
    drop1    < pal.bin > roadram_hi.bin
    rm -f pal.bin roadram.bin
fi

# Fast load
# rm -f sdram_bank*
# dd if=rom.bin of=sdram_bank0.bin ibs=16 skip=1 conv=swab
$JTFRAME/bin/rom2sdram.sh $SYSNAME --header 16 --swab || exit $?

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK $EXTRA $* || exit $?
