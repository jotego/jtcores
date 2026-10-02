#!/bin/bash -e
# Split a scene dump into the BRAM simfiles jtsim loads. One layout, matching
# mame_scripts/dump_burst.lua:
#
#   313400 = fgvram 4096, rozvram 8192, rozgfx 262144, oram0 1024, oram1 1024,
#            lut0 16384, lut1 16384, pal 4096, regs 8, psac 32, gga 16
#
# psac.bin is the Konami 053936 register file. jt053936 opens that exact
# filename itself in simulation, the same way rungun feeds it
#
# regs: gfxctrl, scrx hi/lo, scry hi/lo, 3 spare
split() { dd if=rest.bin of=$1.bin bs=1 skip=$2 count=$3 status=none; }

SIZE=$(wc -c < rest.bin | tr -d ' ')
case "$SIZE" in
313400)
    split fgvram        0   4096
    split rozvram    4096   8192
    split rozgfx    12288 262144
    split oram0    274432   1024
    split oram1    275456   1024
    split lut0     276480  16384
    split lut1     292864  16384
    split pal      309248   4096
    split regs     313344      8
    split psac     313352     32
    split gga      313384     16
    ;;
*)
    echo "rest2bin.sh: unexpected dump size $SIZE"
    exit 1
    ;;
esac
