#!/bin/bash

eval `$JTCFGSTR -core sf -output bash`

MIST=-mist
GAME=sf

function parse_args {
    while [ $# -gt 0 ]; do
        case "$1" in
            -mister)
                echo "MiSTer setup chosen."
                MIST=$1;;
            -g|-game)
                shift
                echo $1
                case "$1" in
                    sfan|sfjan|sfj|sfp|sf|sfua|sfw) GAME=$1;;
                    *)
                        echo "Error: unsupported game $1"
                        exit 1;;
                esac
                echo "Game set to $GAME"
                shift;;
        esac
        shift
    done
}

parse_args $*
# Removes -game from the argument list
for i in $*; do if [[ $i = -g || $i = -game ]]; then shift; shift; fi; done

if [ ! -e $ROM/$GAME.rom ]; then
    echo "Error: the ROM file for $GAME is not present in $ROM"
    exit 1
fi

ln -srf $ROM/$GAME.rom rom.bin
# jtsim_sdram will garble the ROMs, use direct load
# jtsim_sdram -nohex -banks 0x60000 0xa8000 0xec000

# The sdram.hex file cannot be made with bin2hex
# because of the prom_we loader. You need to run goload.sh
# to get sdram.hex

# Generic simulation script from JTFRAME
$JTFRAME/bin/jtsim $MIST \
    -sysname sf \
    -d COLORW=4 -d VIDEO_START=1 -d JT51_NODEBUG\
    -d JTFRAME_SIM_ROMRQ_NOCHECK -d JTFRAME_DWNLD_PROM_ONLY \
    $*
