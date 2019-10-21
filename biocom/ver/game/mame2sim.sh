#!/bin/bash

# Use MAME debugger command files:
#   biocom.cmd and biocom_wp.cmd
#   to obtain the input files and scroll position bytes for the sim

# Characters:
# Convert character MAME memory dump to input files
if [ ! -e drop1 ]; then
    g++ drop1.cc -o drop1 || exit 1
fi

dd if=biocom_char.bin count=4        | drop1 > char_lower.bin 
dd if=biocom_char.bin count=4 skip=4 | drop1 > char_upper.bin 

# Palette 
if [ ! -e pal_bin2hex ]; then
    g++ pal_bin2hex.cc -o pal_bin2hex || exit 1
fi

pal_bin2hex < biocom_pal.bin

# Objects
cp -f biocom_obj.bin objdma.bin

# Scroll 1
drop1 < biocom_scr1.bin | drop1    > scr1_upper.bin
drop1 < biocom_scr1.bin | drop1 -l > scr1_lower.bin

# Scroll 2
drop1 < biocom_scr2.bin | drop1    > scr2_upper.bin
drop1 < biocom_scr2.bin | drop1 -l > scr2_lower.bin

go.sh -d NOSOUND -d NOMAIN -d NOMCU -video 2 \
    -d JTCHAR_UPPER_SIMFILE=',.simfile({SIMID,"_upper.bin"})' \
    -d JTCHAR_LOWER_SIMFILE=',.simfile({SIMID,"_lower.bin"})' \
    -d SIM_SCR1_VPOS=10\'h300 \
    -d SIM_SCR2_VPOS=9\'h100 \
    -deep 