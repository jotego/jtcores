#!/bin/bash

eval `$JTCFGSTR -core gng -output bash`

for i in ../../mist/*hex; do
    if [ ! -e $(basename "$i") ]; then
        if [ -e "$i" ]; then ln -sf "$i"; fi
    fi
done

MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=-mister
    fi
done

# Create default palette files
if [[ ! -e rg_ram.hex || ! -e b_ram.hex ]]; then
    cnt=0;
    while [ $cnt != 256 ]; do
        echo FF >> rg_ram.hex
        echo  0 >> b_ram.hex
        cnt=$((cnt+1))
    done
fi

# Generic simulation script from JTFRAME
$JTFRAME/bin/jtsim $MIST -sysname gng $*