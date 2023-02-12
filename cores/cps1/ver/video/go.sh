#!/bin/bash

echo "Video-only simulations have been integrated into the main 'game' simulation"
exit 0


# The simulation can work loading a local .hex file
# for SDRAM, but it has to be provided in a 8-bit per line format
# use macro SDRAM_HEXFILE or argument -hex to enable this
# The SDRAM file can be obtained from top level simulation in ver/game
# but you need to convert it from 16-bit per line to 8-bit. You can
# use the hex16to8.cc file in this folder to accomplish exactly that.

MACROPREFIX=-D
EXTRA=
MMR=regs.hex

if which cvc64; then
    MACROPREFIX=+define+
    SIM=cvc64
else
if which ncverilog; then
    MACROPREFIX=+define+
    SIM=ncverilog
else
    SIM=iverilog
fi
fi

GAME=ghouls
SAVE=1
RESIZE="-resize 200%"

while [ $# -gt 0 ]; do
    case $1 in
        -g|-game) shift; GAME=$1;;
        -s|-save) shift; SAVE=$1;;
        -hex) EXTRA="$EXTRA ${MACROPREFIX}SDRAM_HEXFILE";;
        -mmr) shift; MMR=$1;;
        -f|-frame) shift; EXTRA="$EXTRA ${MACROPREFIX}FRAMES=$1";;
        -d) shift; EXTRA="$EXTRA ${MACROPREFIX}$1";;
        -noscale)
            RESIZE=
            ;;
        -ar)
            RESIZE="-resize 768x576!";;
        -h|-help)
            echo "-g|-game: selects the game. There must be a folder with the same name"
            echo "-s|-save: selects the save state number"
            echo "-f|-frame: number of frames to simulate"
            echo "-noscale: keep pixel perfect output"
            echo "-ar: resize for correct aspect ratio"
            echo "-d: add verilog macro"
            echo -e "\nExample:\n\tgo.sh -g sf2 -s 2"
            exit 0;;
        *) echo "ERROR: unknown argument $1"; exit 1;;
    esac
    shift
done

# Does the game/snapshot exist?
VRAM_FILE=$GAME/vram$SAVE.bin
REGS_FILE=$GAME/regs$SAVE.hex
ROM_FILE=$JTROOT/rom/$GAME.rom
CFG_FILE=cfg/${GAME}_cfg.hex
if [[ ! -e $REGS_FILE || ! -e $VRAM_FILE || ! -e $ROM_FILE || ! -e $CFG_FILE ]]; then
    echo "ERROR: could not find the required snapshot files"
    ls $VRAM_FILE
    ls $REGS_FILE
    ls $ROM_FILE
    ls $CFG_FILE
    exit 1
fi

CPSB_CONFIG=$(cat $CFG_FILE)

# Link to simulation files
rm -f vram.bin regs.hex rom
cp $VRAM_FILE vram.bin # this file is not linked to avoid overwritting it with new saves from MAME
ln -s $REGS_FILE regs.hex
ln -s $ROM_FILE rom

# Prepare bin files
# Note that the VRAM base address must be manually changed
dd if=vram.bin of=vram_sw.bin conv=swab
# Palette
dd if=vram.bin of=pal.bin count=$((8*1024/512)) skip=$((256*256/512)) # iflag=count_bytes,skip_bytes
# Objects
dd if=vram.bin of=obj.bin count=$((256*4*2/512)) #skip=$((1*256*256/512)) #iflag=count_bytes,skip_bytes

if which ncverilog; then
    ncverilog test.v -f test.f  +access+r +define+SIMULATION \
    +define+VIDEOSIMULATION \
    +define+NCVERILOG $EXTRA \
    +define+MMR_FILE=\"$MMR\" +define+CPSB_CONFIG="$CPSB_CONFIG" $*
else
    iverilog test.v -f test.f -DSIMULATION $EXTRA -DMMR_FILE=\"$MMR\" \
        -DCPSB_CONFIG="$CPSB_CONFIG" \
        -DVIDEOSIMULATION \
        $* -o sim || exit 1
    sim -lxt
fi

rm -f video*.png
#dd if=video.raw of=x.raw count=$((384*240*4)) iflag=count_bytes
convert -size 384x224 -depth 8 RGBA:video.raw $RESIZE video.png
# right aspect ratio:
# convert video.png -resize 598x448 x.png