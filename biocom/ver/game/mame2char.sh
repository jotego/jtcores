#!/bin/bash
# Convert character MAME memory dump to input files
if [ ! -e drop1 ]; then
    g++ drop1.cc -o drop1
fi

dd if=biocom_char.bin count=4        | drop1 > char_lower.bin 
dd if=biocom_char.bin count=4 skip=4 | drop1 > char_upper.bin 
