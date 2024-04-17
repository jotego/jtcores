#!/bin/bash
# Convert character MAME memory dump to input files
if [ ! -e jtutil drop1 ]; then
    g++ jtutil drop1.cc -o jtutil drop1
fi

dd if=biocom_char.bin count=4        | jtutil drop1 > char_lower.bin 
dd if=biocom_char.bin count=4 skip=4 | jtutil drop1 > char_upper.bin 
