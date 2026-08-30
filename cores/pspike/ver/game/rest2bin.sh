#!/bin/bash -e
# Split a scene dump into the BRAM simfiles jtsim loads. Two layouts, told
# apart by size, matching the two dump_burst.lua scripts:
#
#  pspikes   29700 = vram 4096, rascr 4096, oram 1024, lut 16384, pal 4096, regs 4
#  turbofrc  57356 = vram0 8192, vram1 8192, rascr 4096, oram 2048,
#                    lut0 16384, lut1 16384, pal 2048, regs 12
#  karatblz 151562 = vram0 8192, vram1 8192, oram 2048,
#                    lut0 65536, lut1 65536, pal 2048, regs 10
#                    no raster RAM, layer 0 scroll X is a register
split() { dd if=rest.bin of=$1.bin bs=1 skip=$2 count=$3 status=none; }

SIZE=$(wc -c < rest.bin | tr -d ' ')
case "$SIZE" in
29700)
    split vram      0  4096
    split rascr  4096  4096
    split oram   8192  1024
    split lut    9216 16384
    split pal   25600  4096
    split regs  29696     4
    : > vram1.bin
    : > lut1.bin
    cp oram.bin oram1.bin
    ;;
57356)
    split vram      0  8192
    split vram1  8192  8192
    split rascr 16384  4096
    split oram  20480  2048
    split lut   22528 16384
    split lut1  38912 16384
    split pal   55296  2048
    split regs  57344    12
    # both sprite chips read the same RAM, the second one the upper half
    cp oram.bin oram1.bin
    ;;
151562)
    split vram       0  8192
    split vram1   8192  8192
    split oram   16384  2048
    split lut    18432 65536
    split lut1   83968 65536
    split pal   149504  2048
    split regs  151552    10
    : > rascr.bin
    cp oram.bin oram1.bin
    ;;
*)
    echo "rest.bin is $SIZE bytes, no matching scene layout"
    exit 1
    ;;
esac
