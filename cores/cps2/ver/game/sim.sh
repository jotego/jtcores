#!/bin/bash

eval `$JTCFGSTR -core cps1 -output bash`

GAME=spf2t
PATCH=
OTHER=
SCENE=
GOOD=0
TURBO=

while [ $# -gt 0 ]; do
    case $1 in
        -g|-game)  shift; GAME=$1;;
        -s|-scene)
            shift
            SCENE=$1;;
        -p|-patch) shift; PATCH=$1;;
        -turbo)
            TURBO="-d JTCPS_TURBO";;
        -h|-help)
            echo "CPS simulation specific commands"
            echo "   -g|-game   selects game. Use MAME names"
            echo "   -s|-scene  selects simulation scene. Turns off MAIN/SOUND simulation"
            echo "   -turbo     enables turbo mode: DMA does not pause the CPU"
            echo "   ---------------------- "
            $JTFRAME/bin/sim.sh -sysname cps2 -help
            exit 0;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

for i in ddtod ssf2 ssf2t ecofghtr avsp dstlk ringdest \
    armwar xmcota nwarr cybots sfa mmancp2u mmancp2ur1 rmancp2j msh \
    19xx ddsom sfa2 sfz2al spf2t megaman2 qndream  xmvsf batcir vsav mmatrix \
    mshvsf csclub sgemf vhunt2 vsav2 mvsc sfa3 jyangoku hsf2 mpang progear\
    gigawing ssf2xj; do
    if [ $GAME = $i ]; then
        GOOD=1
        break
    fi
done

# Check that the scene exists
if [ -n "$SCENE" ]; then
    if [[ ! -e $GAME/vram${SCENE}.bin || ! -e $GAME/regs${SCENE}.hex \
       || ! -e $GAME/obj${SCENE}.bin ]]; then
        echo "Error: cannot find scene $SCENE files in $GAME folder"
        exit 1
    fi
    MMR_FILE="-d MMR_FILE=\"$GAME/regs${SCENE}.hex\""
    PRIO_SIM="-d PRIO_SIM=$(printf "%d" 0x$(head -n 1 $GAME/prio${SCENE}.hex))"
    OFF_RST=$(printf " -d XOFF_RST=10\'h%s -d YOFF_RST=10\'h%s\n" $(cat $GAME/off${SCENE}.hex))
    OTHER="$OTHER -d NOMAIN -d NOSOUND -video 3"
    SCENE="-game $GAME -scene $SCENE"
    rm sdram_bank?.hex
else
    MMR_FILE=
    PRIO_SIM=
    OFF_RST=
fi

if [ $GOOD = 0 ]; then
    echo "The specified game is not a CPS2 title"
    exit 1
fi

# Prepare ROM file and config file
ln -sf $ROM/$GAME.rom rom.bin
touch rom.bin
g++ rom2hex.cc -o rom2hex || exit $?
rom2hex rom.bin -cps2 $SCENE

CFG_FILE=cps_cfg.hex
if [[ ! -e $CFG_FILE ]]; then
    echo "ERROR: could not find the required snapshot files"
    ls $CFG_FILE
    exit 1
fi

CPSB_CONFIG=$(cat $CFG_FILE)

$JTFRAME/bin/jtsim -mist \
    -sysname cps2 \
    -def ../../hdl/jtcps2.def \
    -d CPSB_CONFIG="$CPSB_CONFIG"  \
    -d JT9346_SIMULATION -d JTDSP16_FWLOAD -d SKIP_RAMCLR \
    $MMR_FILE $PRIO_SIM $OFF_RST \
    -d JTFRAME_SIM_ROMRQ_NOCHECK $TURBO \
    $OTHER