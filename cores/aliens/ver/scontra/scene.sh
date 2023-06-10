#!/bin/bash

# Video simulation

if [ ! -e SCONTRA.RAM ]; then
    echo "Generate SCONTRA.RAM on MiST by saving the NVRAM"
    exit 0
fi

# 16 kB Tilemap VRAM
dd if=SCONTRA.RAM of=scr1.bin count=16
dd if=SCONTRA.RAM of=scr0.bin count=16 skip=16
# 2 kB PAL
dd if=SCONTRA.RAM of=pal.bin count=4 skip=32
# 1 kB Sprite LUT
dd if=SCONTRA.RAM of=obj.bin count=2 skip=36
# 8 bytes for tilemap MMR
dd if=SCONTRA.RAM of=scr_mmr.bin count=1 skip=2432 ibs=8
# 8 bytes for object MMR
dd if=SCONTRA.RAM of=obj_mmr.bin count=1 skip=2433 ibs=8
# Priority config
dd if=SCONTRA.RAM of=prio.bin count=1 skip=19471 ibs=1

jtsim -sysname aliens -nosnd -d NOMAIN -video 3 -zoom -w $*