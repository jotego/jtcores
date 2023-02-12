#!/bin/bash

eval `$JTCFGSTR -core cps1 -output bash`

GAME=punisher
PATCH=
OTHER=
SCENE=
GOOD=0

while [ $# -gt 0 ]; do
    case $1 in
        -g|-game)  shift; GAME=$1;;
        -s|-scene)
            shift
            SCENE=$1;;
        -p|-patch) shift; PATCH=$1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

for i in wof wofa wofj wofu dino dinoa dinohunt dinoj dinou punisher punisherbz punisherh punisherj punisheru mbomberj slammast slammastu mbombrd mbombrdj; do
    if [ $GAME = $i ]; then
        GOOD=1
        break
    fi
done

if [ $GOOD = 0 ]; then
    echo "The specified game is not a CPS 1.5 title"
    exit 1
fi

# Check that the scene exists
if [ -n "$SCENE" ]; then
    if [[ ! -e $GAME/vram${SCENE}.bin || ! -e $GAME/regs${SCENE}.hex ]]; then
        echo "Error: cannot find scene $SCENE files in $GAME folder"
        exit 1
    fi
    MMR_FILE="-d MMR_FILE=\"$GAME/regs${SCENE}.hex\""
    OTHER="$OTHER -d NOMAIN -d NOSOUND -d NOZ80 -video 3"
    SCENE="-game $GAME -scene $SCENE"
    rm sdram_bank?.hex
else
    MMR_FILE=
fi

# Prepare ROM file and config file
make || exit $?
ln -sf $ROM/$GAME.rom rom.bin
rom2hex rom.bin $SCENE || exit $?

CFG_FILE=cps_cfg.hex
if [[ ! -e $CFG_FILE ]]; then
    echo "ERROR: could not find the required snapshot files"
    ls $CFG_FILE
    exit 1
fi

CPSB_CONFIG=$(cat $CFG_FILE)

# Generic simulation script from JTFRAME
$JTFRAME/bin/jtsim -mist \
    -sysname cps15 \
    -def ../../hdl/jtcps15.def \
    -d CPSB_CONFIG="$CPSB_CONFIG"  \
    -d JT9346_SIMULATION -d JTDSP16_FWLOAD -d SKIP_RAMCLR \
    $MMR_FILE \
    $OTHER
# -d JTCPS_TURBO