#!/bin/bash
CORE=$(basename $(dirname $(dirname $(pwd))))

function try {
    while [ $# -gt 0 ]; do
        if [ ! -e $1 ]; then
            shift
            continue
        fi
        cp $1/ngp nvram.bin
        return 0
    done
    return 1
}

INPUTS=

rm -f *_lo.bin *_hi.bin pal.bin regsram.bin

jtutil drop1 -l < rom.bin > rom_lo.bin
jtutil drop1    < rom.bin > rom_hi.bin

while [ $# -gt 0 ]; do
    case $1 in
        -nvram)
            if [ ! -e nvram.bin ]; then
                if ! try nvram.old ~/.mame/nvram/ngp $JOTEGO/simfiles/$CORE; then
                    echo "Create a NVRAM file in MAME first"
                    exit 1
                fi
            fi
            if [ -e fixnvram.go ]; then
                go run fixnvram.go  # prevents running the setup
            fi
            jtutil drop1 -l < nvram.bin > nvram_lo.bin
            jtutil drop1    < nvram.bin > nvram_hi.bin
            # Change reset vector, so it does not wait for the power-up button press
            if [ $CORE = ngp ]; then
                printf "\x18" | dd of=rom_hi.bin bs=1 seek=`printf "%d" 0x7f80` count=1 conv=notrunc
                printf "\x00" | dd of=rom_lo.bin bs=1 seek=`printf "%d" 0x7f80` count=1 conv=notrunc
            else
                printf "\x20" | dd of=rom_hi.bin bs=1 seek=`printf "%d" 0x7f80` count=1 conv=notrunc
                printf "\x4A" | dd of=rom_lo.bin bs=1 seek=`printf "%d" 0x7f80` count=1 conv=notrunc
            fi
            OTHER="$OTHER -d NVRAM"
            ;;
        -cart)
            shift
            ln -sf "$1" cart.bin || exit $?
            dd if=cart.bin of=sdram_bank1.bin conv=swab
            CART_MB=$(expr $(stat -L -c %s cart.bin) / 1024 / 1024)
            # Determine the value for CARTSIZE based on the file size
            if [ $CART_MB -lt 1 ]; then
              CARTSIZE=1
            elif [ $CART_MB -lt 2 ]; then
              CARTSIZE=2
            else
              CARTSIZE=4
            fi
            OTHER="$OTHER -d CARTSIZE=$CARTSIZE"
            echo "NB: the NEOGEO logo sequence takes 479 frames"
            ;;
        -s)
            shift
            SCENE=$1
            OTHER="$OTHER -d NOMAIN -d NOSND -video 2 -w -zoom"
            if [ ! -e scenes/$SCENE/vram.bin ]; then
                echo Cannot find scene $SCENE
                exit 1
            fi
            ;;
        -inputs)
            OTHER="$OTHER $1 $2"
            shift
            INPUTS=1;;
        *)
            OTHER="$OTHER $1";;
    esac
    shift
done

if [ -z "$INPUTS" ]; then
    # skip the logo animation
    OTHER="$OTHER -inputs nologo.hex"
fi

function split {
    cat ${1}ram.bin | jtutil drop1    > ${1}_hi.bin
    cat ${1}ram.bin | jtutil drop1 -l > ${1}_lo.bin
}

if [ -n "$SCENE" ]; then
    dd if=scenes/$SCENE/vram.bin of=regsram.bin ibs=64 count=1 2> /dev/null
    dd if=scenes/$SCENE/vram.bin of=pal.bin ibs=1 count=25 skip=256 2> /dev/null
    dd if=scenes/$SCENE/vram.bin of=objram.bin  ibs=256 count=1 skip=8 2> /dev/null
    dd if=scenes/$SCENE/vram.bin of=scr1ram.bin count=4 skip=8 2> /dev/null
    dd if=scenes/$SCENE/vram.bin of=scr2ram.bin count=4 skip=12 2> /dev/null
    dd if=scenes/$SCENE/vram.bin of=chram.bin count=16 skip=16 2> /dev/null
    for i in obj ch scr1 scr2 regs; do split $i; done
    # rm -f objram.bin charam.bin
fi

echo jtsim $OTHER
jtsim -sysname $CORE -d JTFRAME_SIM_DIPS=0 $OTHER
