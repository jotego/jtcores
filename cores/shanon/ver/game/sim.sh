#!/bin/bash

EXTRA=

eval `jtframe cfgstr shanon -o bash`

dd if=epr-10642.47 of=rd0_lo.bin count=32 > /dev/null
dd if=epr-10642.47 of=rd0_hi.bin skip=32 count=32 > /dev/null

if [ -e obj.bin ]; then
    jtutil drop1    < obj.bin >  obj_hi.bin
    jtutil drop1    < obj.bin >> obj_hi.bin
    jtutil drop1 -l < obj.bin >  obj_lo.bin
    jtutil drop1 -l < obj.bin >> obj_lo.bin
fi

if [ -e roadram.bin ]; then
    jtutil drop1    < roadram.bin > roadram_lo.bin
    jtutil drop1 -l < roadram.bin > roadram_hi.bin
    EXTRA="$EXTRA -d SIM_ROAD_CTRL"
fi

# Core dump from MiST
if [ -e OUTRUN.RAM ]; then
    dd if=OUTRUN.RAM of=pal.bin count=16
    jtutil drop1 -l < pal.bin > pal_lo.bin
    jtutil drop1    < pal.bin > pal_hi.bin
    dd if=OUTRUN.RAM of=roadram.bin count=8 skip=16
    jtutil drop1 -l < pal.bin > roadram_lo.bin
    jtutil drop1    < pal.bin > roadram_hi.bin
    rm -f pal.bin roadram.bin
fi

jtsim $*

