#!/bin/bash

# Use MAME debugger command files:
#   tora.cmd and tora_wp.cmd
#   to obtain the input files and scroll position bytes for the sim

SCRHPOS=0000
SCRVPOS=0000
SCRBANK=0
SCENE=

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--scrhpos)
            shift
            SCRHPOS=$1;;
        -v|--scrvpos)
            shift
            SCRVPOS=$1;;
        -b|--bank)
            shift
            SCRBANK=$1;;
        -s|--scene)
            shift
            mkdir -p $1
            SCENE=$1;;
        -h|--help)
            cat <<EOF
cpsnap.sh: copies MAME snapshot to a usable format in a folder

Usage: cpsnap.sh <-s scene_folder>

-s or --scene  : sets the scene folder
-h or --scrhpos: indicate horizontal scroll 1 in hexadecimal
-v or --scrvpos: indicate vertical   scroll 1 in hexadecimal
-b or --bank   : sets the scroll bank (1 or 0)
EOF
            exit 0;;
        *) echo "Unknown option $1. Use -help to see the list of options"; exit 1;;
    esac
    shift
done

if [ -z "$SCENE" ]; then
    echo "The scene name must be assigned with -s"
    exit 1
fi

# Scroll and bank values
cat >$SCENE/scrpos.sh <<EOF
SIM_SCR1_HPOS=$SCRHPOS
SIM_SCR1_VPOS=$SCRVPOS
SIM_SCR_BANK=$SCRBANK
EOF

# Characters:
# Convert character MAME memory dump to input files
if ! which jtutil drop1; then
    echo Cannot locate jtutil drop1 command.
    echo is \$JTUTIL/bin in your PATH?
    exit 1
fi

dd if=tora_char.bin 2>/dev/null | jtutil drop1    > $SCENE/char_lo.bin
dd if=tora_char.bin 2>/dev/null | jtutil drop1 -l > $SCENE/char_hi.bin

# Palette
if [ ! -e pal_bin2hex ]; then
    g++ pal_bin2hex.cc -o pal_bin2hex || exit 1
fi

pal_bin2hex < tora_pal.bin
mv -v palr.hex $SCENE/palr.hex
mv -v palgb.hex $SCENE/palgb.hex

# Objects
mv -fv tora_obj.bin $SCENE/objdma.bin
