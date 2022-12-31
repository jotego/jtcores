#!/bin/bash

if [ ! -e rom.bin ]; then
    ln -sr $ROM/vulgus.rom rom.bin
fi

if [ -e char.bin ]; then
    dd if=char.bin of=char_lo.bin count=2
    dd if=char.bin of=char_hi.bin count=2 skip=2
fi

# Generic simulation script from JTFRAME
jtsim $* \
    -d JTCHAR_LOWER_SIMFILE=',.simfile("char_lo.bin")' \
    -d JTCHAR_UPPER_SIMFILE=',.simfile("char_hi.bin")'
