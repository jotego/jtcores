#!/bin/bash

if [ -e aliens.bin ]; then
    dd if=aliens.bin of=scr0.bin count=16
    dd if=aliens.bin of=scr1.bin count=16 skip=16
fi

jtsim $*