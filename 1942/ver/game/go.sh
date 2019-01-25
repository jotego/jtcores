#!/bin/bash

function zero_file {
    rm -f $1
    cnt=$2
    while [ $cnt != 0 ]; do
        echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
        cnt=$((cnt-16))
    done;
}

DUMP=
CHR_DUMP=NOCHR_DUMP
RAM_INFO=NORAM_INFO
FIRMWARE=gng_test.s
VGACONV=NOVGACONV
LOADROM=
FIRMONLY=NOFIRMONLY
MAXFRAME=
SIM_MS=1
SIMULATOR=iverilog
FASTSIM=
TOP=game_test
MIST=
MACROPREFIX=-D

ARGNUMBER=1
while [ $# -gt 0 ]; do
case "$1" in
    "-w" | "-deep")
        DUMP=${MACROPREFIX}DUMP
        echo Signal dump enabled
        if [ $1 = "-deep" ]; then DUMP="$DUMP ${MACROPREFIX}DEEPDUMP"; fi
        ;;
    "-frames")
        shift
        if [ "$1" = "" ]; then
            echo "Must specify number of frames to simulate"
            exit 1
        fi
        MAXFRAME="${MACROPREFIX}MAXFRAME=$1"
        echo Simulate up to $1 frames
        ;;
    "-mist")
        TOP=mist_test
        MIST="-f mist.f"
        ;;
    "-nosnd")
        FASTSIM="$FASTSIM ${MACROPREFIX}NOSOUND";;
    "-nocolmix")
        FASTSIM="$FASTSIM ${MACROPREFIX}NOCOLMIX";;
    "-noscr")
        FASTSIM="$FASTSIM ${MACROPREFIX}NOSCR";;
    "-nochar")
        FASTSIM="$FASTSIM ${MACROPREFIX}NOCHAR";;
    "-time")
        shift
        if [ "$1" = "" ]; then
            echo "Must specify number of milliseconds to simulate"
            exit 1
        fi
        SIM_MS="$1"
        echo Simulate $1 ms
        ;;
    "-firmonly")
        FIRMONLY=FIRMONLY
        echo Firmware dump only
        ;;
    "-t")
        # is there a file name?        
        if [[ "${2:0:1}" != "-" && $# -gt 1  ]]; then
            shift
            FIRMWARE=$1
        else
            FIRMWARE=bank_check.s
        fi
        echo "Using test firmware $FIRMWARE"
        LOADROM=${MACROPREFIX}TESTROM
        if ! z80asm $FIRMWARE -o test.bin -l > $(basename $FIRMWARE .s).lst; then
            exit 1
        fi        
        ;;
    "-ch")
        CHR_DUMP=CHR_DUMP
        echo Character dump enabled
        ;;
    "-info")
        RAM_INFO=RAM_INFO
        echo RAM information enabled
        ;;
    "-vga")
        VGACONV=VGACONV
        echo VGA conversion enabled
        ;;
    "-load")
        LOADROM=${MACROPREFIX}LOADROM
        echo ROM load through SPI enabled
        if [ ! -e ../../../rom/JT1942.rom ]; then
            echo "Missing file JT1942.rom in rom folder"
            echo "Run 1942rom.py in rom folder to generate it."
            exit 1
        fi
        ;;
    "-lint")
        SIMULATOR=verilator;;
    "-nc")
        SIMULATOR=ncverilog        
        MACROPREFIX="+define+"
        if [ $ARGNUMBER != 1 ]; then
            echo "ERROR: -nc must be the first argument so macros get defined correctly"
            exit 1
        fi
        ;;
    *) echo "Unknown option $1"; exit 1;;
esac
    shift
    ARGNUMBER=$((ARGNUMBER+1))
done

if [ $FIRMONLY = FIRMONLY ]; then exit 0; fi

function add_dir {
    for i in $(cat $1/$2); do
        echo $1/$i
    done
}

# HEX files with initial contents for some of the RAMs
function clear_hex_file {
    cnt=0
    rm -f $1.hex
    while [ $cnt -lt $2 ]; do 
        echo 0 >> $1.hex
        cnt=$((cnt+1))
    done    
}

clear_hex_file obj_buf  128

case $SIMULATOR in
iverilog)   iverilog -g2005-sv ${TOP}.v \
        -f game.f \
        ../../../modules/ver/{mt48lc16m16a2,altera_mf,quick_sdram}.v \
        ../../../modules/tv80/*.v $MIST \
        ../../../modules/jtgng_sdram.v \
        -s $TOP -o sim -DSIM_MS=$SIM_MS -DSIMULATION \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM $FASTSIM \
        $MAXFRAME $OBJTEST -DIVERILOG \
    && sim -lxt;;
ncverilog)
    ncverilog +access+r +nc64bit ${TOP}.v +define+NCVERILOG \
        -f game.f \
        ../../../modules/ver/mt48lc16m16a2.v \
        ../../../modules/jtgng_sdram.v \
        +define+SIM_MS=$SIM_MS +define+SIMULATION \
        $DUMP $LOADROM $FASTSIM \
        $MAXFRAME $OBJTEST \
        ../../../modules/tv80/*.v \
        $MIST;;
        #-ncvhdl_args,-V93 ../../../modules/t80/T80pa.vhd \
verilator)
    verilator -I../../hdl \
        -f game.f \
        ../../../modules/tv80/*.v \
        ../../../modules/ver/quick_sdram.v \
        --top-module jt1942_game -o sim \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM -DFASTSDRAM \
        -DVERILATOR_LINT \
        $MAXFRAME $OBJTEST -DSIM_MS=$SIM_MS --lint-only;;
esac

# if [ $CHR_DUMP = CHR_DUMP ]; then
#     rm frame*png
#     for i in frame_*; do
#         name=$(basename "$i")
#         extension="${name##*.}"
#         if [ "$extension" == png ]; then continue; fi
#         ../../../cc/frame2png "$i"
#         mv output.png "$i.png"
#         mv "$i" old/"$i"
#     done
# fi