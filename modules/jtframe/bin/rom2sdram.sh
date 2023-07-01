#!/bin/bash

HEADER=0
CONV=conv=notrunc
CORE=
VERBOSE="/dev/null"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--header)
            shift
            HEADER=$( printf "%d" $1 );;
        -s|--swab)
            CONV=${CONV},swab;;
        -v|--verbose)
            VERBOSE="/dev/stderr";;
        -h|--help)
            cat<<EOF
rom2sdram [corename] [--header len] [--swab]
    [corename]      optional core name
    -h,--header len
    -s,--swab       Swap byte order
    -v,--verbose    Show the output of the dd commands

    Reads rom.bin and creates sdram_bank[0,1,2,3] files for simulation
    if the JTFRAME_BA1_START, JTFRAME_BA2_START and JTFRAME_BA3_START environment variables
    are defined, the sdram_bank[1,2,3].bin files will be created, otherwise
    only sdram_bank0 will be created.

    If a core name is specified, then 'jtframe cfgstr <corename>' will be run
    to get the environment variables from it
EOF
            exit 0;;
        *)
            if [ -z "$CORE" ]; then
                CORE=$1
                if [ ! -d $CORES/$1 ]; then
                    echo "ERROR: (rom2sdram.sh) core not found in $CORES"
                    exit 1
                fi
            else
                echo "ERROR: (rom2sdram.sh) core name defined twice ($CORE and $1)"
                exit 1
            fi
            ;;
    esac
    shift
done

if [ ! -z "$CORE" ]; then
    eval `jtframe cfgstr $CORE --target mist --output bash`
fi

if [ ! -e rom.bin ]; then
    echo "ERROR: (rom2sdram.sh) cannot open rom.bin"
    exit 1
fi

# Convert from hexadecimal to decimal
# if the macros are not defined, printf will return a 0
JTFRAME_BA1_START=$( printf "%d" $JTFRAME_BA1_START )
JTFRAME_BA2_START=$( printf "%d" $JTFRAME_BA2_START )
JTFRAME_BA3_START=$( printf "%d" $JTFRAME_BA3_START )

BA1_LEN=$((JTFRAME_BA2_START-JTFRAME_BA1_START))
BA2_LEN=$((JTFRAME_BA3_START-JTFRAME_BA2_START))

rm -f sdram_bank?.{hex,bin}
dd if=/dev/zero of=sdram_bank0.bin count=16384 2>  $VERBOSE

if [ $JTFRAME_BA1_START -gt 0 ]; then
    dd if=rom.bin of=sdram_bank0.bin $CONV iflag=count_bytes,skip_bytes count=$JTFRAME_BA1_START skip=$HEADER 2>  $VERBOSE
    dd if=/dev/zero of=sdram_bank1.bin count=16384 2>  $VERBOSE
    dd if=rom.bin of=sdram_bank1.bin $CONV iflag=count_bytes,skip_bytes count=$BA1_LEN skip=$((HEADER+$JTFRAME_BA1_START)) 2>  $VERBOSE
    if [ $JTFRAME_BA2_START -gt 0 ]; then
        dd if=/dev/zero of=sdram_bank2.bin count=16384 2>  $VERBOSE
        dd if=rom.bin of=sdram_bank2.bin $CONV iflag=count_bytes,skip_bytes count=$BA2_LEN skip=$((HEADER+$JTFRAME_BA2_START)) 2>  $VERBOSE
    fi
    if [ $JTFRAME_BA3_START -gt 0 ]; then
        dd if=/dev/zero of=sdram_bank3.bin count=16384 2>  $VERBOSE
        dd if=rom.bin of=sdram_bank3.bin $CONV iflag=count_bytes,skip_bytes skip=$((HEADER+$JTFRAME_BA3_START)) 2>  $VERBOSE
    fi
else
    dd if=rom.bin of=sdram_bank0.bin 2>  $VERBOSE
fi