#!/bin/bash
MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

if [ -e char.bin ]; then
    dd if=char.bin of=char_lo.bin count=2
    dd if=char.bin of=char_hi.bin count=2 skip=2
fi

export GAME_ROM_PATH=../../../rom/JT1942.rom
export MEM_CHECK_TIME=68_000_000
export CONVERT_OPTIONS="-rotate -90 -resize 300%x300%"
#export CONVERT_OPTIONS="-resize 300%x300%"
export YM2149=1

# Generic simulation script from JTFRAME
jtsim $MIST -d GAME_ROM_LEN=240128 -d VERTICAL_SCREEN \
     $* -sysname 1942 \
    -d JTCHAR_LOWER_SIMFILE=',.simfile("char_lo.bin")' \
    -d JTCHAR_UPPER_SIMFILE=',.simfile("char_hi.bin")'

# Unused SDRAM banks
rm -f sdram_bank{1,2,3}.hex