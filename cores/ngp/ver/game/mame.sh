#!/bin/bash
rm -rf ~/.mame/nvram/ngp*
if [ -e nvram.bin ]; then
    cp nvram.bin ~/.mame/nvram || exit 0
    echo "nvram.bin copied to MAME"
fi

mame ngp -debug -debugscript debug.mame -rompath roms -nvram_save

