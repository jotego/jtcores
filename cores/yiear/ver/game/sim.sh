#!/bin/bash

#jtsim_sdram
if [ -e vram.bin ]; then
    cat vram.bin | jtutil drop1    > vram_hi.bin
    cat vram.bin | jtutil drop1 -l > vram_lo.bin
fi

jtsim $*
