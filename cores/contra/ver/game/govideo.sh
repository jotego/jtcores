#!/bin/bash

OTHER=

while [ $# -gt 0 ]; do
    case $1 in
        -s)
            shift
            if [ ! -d scene${1} ]; then
                echo "Cannot find scene #" $1
                exit 1
            fi
            cp scene${1}/* .;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

head gfx_cfg.hex -n 8 > gfx1_cfg.hex
tail gfx_cfg.hex -n 8 > gfx2_cfg.hex

dd if=gfx1.bin of=gfx1_attr.bin count=4
dd if=gfx1.bin of=gfx1_code.bin count=4 skip=4
dd if=gfx1.bin of=gfx1_obj.bin  count=8 skip=8

dd if=gfx2.bin of=gfx2_attr.bin count=4
dd if=gfx2.bin of=gfx2_code.bin count=4 skip=4
dd if=gfx2.bin of=gfx2_obj.bin  count=8 skip=8

sim.sh -d GFX_ONLY -d NOSOUND -video 2 -deep -d VIDEO_START=1 $OTHER