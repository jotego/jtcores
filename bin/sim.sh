#!/bin/bash

function zero_file {
    rm -f $1
    cnt=$2
    while [ $cnt != 0 ]; do
        echo -e "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0" >> $1
        cnt=$((cnt-16))
    done;
}

if [ ! -e zeros1k.bin ]; then
    dd if=/dev/zero of=zeros1k.bin count=2
fi

if [ ! -e zeros512.bin ]; then
    dd if=/dev/zero of=zeros512.bin count=1
fi

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
EXTRA=
ARGNUMBER=1

rm -f test2.bin

function add_dir {
    for i in $(cat $1/$2); do
        fn="$1/$i"
        if [ ! -e "$fn" ]; then
            (>&2 echo "Cannot find file $fn")
            exit 1
        fi
        echo $fn
    done
}

function find_core_name {
    while [ $# -gt 0 ]; do
        if [ "$1" = "-sysname" ]; then
            echo $2
        fi
        shift
    done    
}

# Which core is this for?
SYSNAME=$(find_core_name $*)
PERCORE=

case "$SYSNAME" in
    "")
        echo "ERROR: Needs system name. Use -sysname"
        exit 1;;
    gng)  PERCORE=$(add_dir ../../../modules/jt12/hdl jt03.f);;
    1942) PERCORE=$(add_dir ../../../modules/jt12/jt49/hdl jt49.f);;
esac
# switch to NCVerilog if available
if which ncverilog; then
    SIMULATOR=ncverilog        
    MACROPREFIX="+define+"
fi

while [ $# -gt 0 ]; do
case "$1" in
    "-sysname") shift;; # ignore here
    "-w" | "-deep")
        DUMP=${MACROPREFIX}DUMP
        echo Signal dump enabled
        if [ $1 = "-deep" ]; then DUMP="$DUMP ${MACROPREFIX}DEEPDUMP"; fi
        ;;
    "-d")
        shift
        EXTRA="$EXTRA ${MACROPREFIX}$1"
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
        if [ $SIMULATOR == iverilog ]; then
            MIST=$(add_dir ../../../modules/mist mist_iverilog.f)
        else
            MIST="-F ../../../modules/mist/mist.f"
        fi
        MIST="$MIST ../../hdl/jt${SYSNAME}_mist.v"
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
        LOADROM="${MACROPREFIX}TESTROM ${MACROPREFIX}FIRMWARE_SIM"
        if ! z80asm $FIRMWARE -o test.bin -l; then
            exit 1
        fi        
        ;;
    "-t2")
        # is there a file name?        
        if [[ "${2:0:1}" != "-" && $# -gt 1  ]]; then
            shift
            FIRMWARE2=$1
        else
            FIRMWARE2=bank_check.s
        fi
        echo "Using test firmware $FIRMWARE2 for second CPU"
        LOADROM=${MACROPREFIX}TESTROM
        if ! z80asm $FIRMWARE2 -o test2.bin -l; then
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

if [ "$EXTRA" != "" ]; then
    echo Verilog macros: "$EXTRA"
fi

case $SIMULATOR in
iverilog)   
    iverilog -g2005-sv $MIST ${TOP}.v \
        -f game.f $PERCORE \
        $(add_dir ../../../modules/ver sim.f ) \
        ../../../modules/tv80/*.v  \
        -s $TOP -o sim -DSIM_MS=$SIM_MS -DSIMULATION \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM $FASTSIM \
        $MAXFRAME -DIVERILOG $EXTRA \
    && sim -lxt;;
ncverilog)
    ncverilog +access+r +nc64bit ${TOP}.v +define+NCVERILOG \
        -f game.f $PERCORE \
        -F ../../../modules/ver/sim.f $MIST \
        +define+SIM_MS=$SIM_MS +define+SIMULATION \
        $DUMP $LOADROM $FASTSIM \
        $MAXFRAME \
        -ncvhdl_args,-V93 ../../../modules/t80/T80{pa,_ALU,_Reg,_MCode,""}.vhd \
        ../../../modules/tv80/*.v \
        $MIST $EXTRA;;
verilator)
    verilator -I../../hdl \
        -f game.f $PERCORE \
        ../../../modules/tv80/*.v \
        ../../../modules/ver/quick_sdram.v \
        --top-module jt1942_game -o sim \
        $DUMP -D$CHR_DUMP -D$RAM_INFO -D$VGACONV $LOADROM -DFASTSDRAM \
        -DVERILATOR_LINT \
        $MAXFRAME -DSIM_MS=$SIM_MS --lint-only $EXTRA;;
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