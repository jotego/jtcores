#!/bin/bash
# The game needs a valid EEPROM image to boot: use MAME's moomesa.nv as nvram.bin
if [ ! -e nvram.bin ]; then
    echo "nvram.bin missing: copy MAME's moomesa.nv here" >&2
    exit 1
fi
jtsim -video 400 -w "$@"
