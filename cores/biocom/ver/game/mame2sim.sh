#!/bin/bash

# Use MAME debugger command files:
#   biocom.cmd and biocom_wp.cmd
#   to obtain the input files and scroll position bytes for the sim

SCR1HPOS=0000
SCR2HPOS=0000
SCR1VPOS=0300
SCR2VPOS=0100

while [ $# -gt 0 ]; do
case "$1" in
    -h1|-scr1hpos)
        shift
        SCR1HPOS=$1;;
    -h2|-scr2hpos)
        shift
        SCR2HPOS=$1;;
    -v1|-scr1vpos)
        shift
        SCR1VPOS=$1;;
    -v2|-scr2vpos)
        shift
        SCR2VPOS=$1;;
    -help)
        cat <<EOF
-h1 or -scr1hpos: indicate horizontal scroll 1 in hexadecimal
-h2 or -scr2hpos: indicate horizontal scroll 2 in hexadecimal
-v1 or -scr1vpos: indicate vertical   scroll 1 in hexadecimal
-v2 or -scr2vpos: indicate vertical   scroll 2 in hexadecimal
EOF
        exit 0;;
    *) echo "Unknown option $1. Use -help to see the list of options"; exit 1;;        
esac
shift
done

# Characters:
# Convert character MAME memory dump to input files
if [ ! -e jtutil drop1 ]; then
    g++ jtutil drop1.cc -o jtutil drop1 || exit 1
fi

dd if=biocom_char.bin count=4        | jtutil drop1 > char_lower.bin 
dd if=biocom_char.bin count=4 skip=4 | jtutil drop1 > char_upper.bin 

# Palette 
if [ ! -e pal_bin2hex ]; then
    g++ pal_bin2hex.cc -o pal_bin2hex || exit 1
fi

pal_bin2hex < biocom_pal.bin

# Objects
cp -f biocom_obj.bin objdma.bin

# Scroll 1
jtutil drop1 < biocom_scr1.bin | jtutil drop1    > scr1_upper.bin
jtutil drop1 < biocom_scr1.bin | jtutil drop1 -l > scr1_lower.bin

# Scroll 2
jtutil drop1 < biocom_scr2.bin | jtutil drop1    > scr2_upper.bin
jtutil drop1 < biocom_scr2.bin | jtutil drop1 -l > scr2_lower.bin

go.sh -d NOSOUND -d NOMAIN -d NOMCU -video 2 \
    -d JTCHAR_UPPER_SIMFILE=',.simfile({SIMID,"_upper.bin"})' \
    -d JTCHAR_LOWER_SIMFILE=',.simfile({SIMID,"_lower.bin"})' \
    -d SIM_SCR1_VPOS=10\'h$SCR1VPOS \
    -d SIM_SCR2_VPOS=9\'h$SCR2VPOS \
    -d SIM_SCR1_HPOS=10\'h0$SCR1HPOS \
    -d SIM_SCR2_HPOS=10\'h0$SCR2HPOS \
    -deep $*