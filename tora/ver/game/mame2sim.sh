#!/bin/bash

# Use MAME debugger command files:
#   tora.cmd and tora_wp.cmd
#   to obtain the input files and scroll position bytes for the sim

SCRHPOS=0000
SCRVPOS=0000
SCRBANK=0
TEST=
EXTRA=

while [ $# -gt 0 ]; do
case "$1" in
    -h|-scrhpos)
        shift
        SCRHPOS=$1;;
    -v|-scrvpos)
        shift
        SCRVPOS=$1;;
    -b|-bank)
        shift
        SCRBANK=$1;;
    -t|-test)
        TEST=echo;;
    :)
        shift
        EXTRA="$*";;
    -help)
        cat <<EOF
-h or -scrhpos: indicate horizontal scroll 1 in hexadecimal
-v or -scrvpos: indicate vertical   scroll 1 in hexadecimal
-b or -bank   : sets the scroll bank (1 or 0)
-t or -test   : show the go.sh command without executing it
EOF
        exit 0;;
    *) echo "Unknown option $1. Use -help to see the list of options"; exit 1;;        
esac
if [ "$EXTRA" != "" ]; then
    break
fi
shift
done

# Characters:
# Convert character MAME memory dump to input files
if ! which drop1; then
    echo Cannot locate drop1 command.
    echo is jtframe/bin in your PATH?
    exit 1
fi

dd if=tora_char.bin 2>/dev/null | drop1 > char_lower.bin 
dd if=tora_char.bin 2>/dev/null | drop1 -l > char_upper.bin 

# Palette 
if [ ! -e pal_bin2hex ]; then
    g++ pal_bin2hex.cc -o pal_bin2hex || exit 1
fi

pal_bin2hex < tora_pal.bin

# Objects
cp -f tora_obj.bin objdma.bin
# -time 17 \
$TEST go.sh -d NOSOUND -d NOMAIN -d NOMCU -video 5 \
    -d JTCHAR_UPPER_SIMFILE=',.simfile({"char_upper.bin"})' \
    -d JTCHAR_LOWER_SIMFILE=',.simfile({"char_lower.bin"})' \
    -d SIM_SCR_HPOS=16\'h$SCRHPOS \
    -d SIM_SCR_VPOS=16\'h$SCRVPOS \
    -d SIM_SCR_BANK=1\'b$SCRBANK \
    -deep $EXTRA
