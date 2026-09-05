#!/bin/bash
# Simulation driver for the Space Harrier core.
#
#   ./sim.sh                    boot the default set
#   ./sim.sh -setname enduror   another set from release/mra
#   ./sim.sh -s <path>          replay a scene dump
#   ./sim.sh -video -time 100   dump frames for 100 ms
#
# Options are passed straight through to jtsim; run "jtsim -help" for the list.
# This script only does what jtsim cannot: pick the .rom, build the SDRAM bank
# files, and carve out the MCU image.

set -e

SYSNAME=harier
GAME=sharrier

eval `jtframe cfgstr $SYSNAME --target=mist --output=bash`

# -setname selects the ROM as well as the simulated set, so mirror it here
ARGS=("$@")
for i in "${!ARGS[@]}"; do
    if [ "${ARGS[$i]}" = "-setname" ]; then
        GAME="${ARGS[$((i+1))]}"
    fi
done

if [ ! -e "$ROM/$GAME.rom" ]; then
    echo "Cannot find $ROM/$GAME.rom -- run 'jtframe mra $SYSNAME' first"
    exit 1
fi

ln -sf "$ROM/$GAME.rom" rom.bin

rm -f sdram_bank?.*
jtutil sdram $SYSNAME --sim

# jtframe_8751mcu keeps its own program ROM, so the MCU image is not an SDRAM
# bank and jtutil does not emit it. Carve it out of the same .rom the core
# loads, so the two cannot drift apart. Read only in simulation, through the
# ROMBIN parameter on jtframe_8751mcu.
#
# Without this the MCU executes zeros, which looks exactly like a boot failure
# and sends you hunting in the wrong place.
dd if=rom.bin of=mcu.bin bs=4096 count=1 status=none \
   iflag=skip_bytes skip=$(( JTFRAME_HEADER + MCU_START ))

if [ ! -s mcu.bin ]; then
    echo "mcu.bin is empty -- check MCU_START against the generated MRA"
    exit 1
fi

# 0201 is LJMP, the 8051 reset vector. Anything else means the offset is wrong.
if [ "$(xxd -p -l2 mcu.bin)" != "0201" ]; then
    echo "mcu.bin does not start with an 8051 reset vector -- wrong offset?"
    exit 1
fi

# The road (315-5025) and sprite-zoom ROMs are on-chip BROMs in the FPGA, filled
# from the download stream, not SDRAM banks -- so jtutil does not emit them. In
# Verilator the BROMs init from raw .bin files instead, so carve them out of the
# same .rom, exactly like mcu.bin above. Without them u_brom_road/u_brom_zoom
# read zero and log "cannot open file", which looks like a blank road/zoom.
#
# epr-7181 (road, ROAD_START, 0x8000) is downloaded as two interleaved halves,
# low byte then high byte per 16-bit word (the MRA's map="01"/map="10"). The BROM
# reads it back as SIMFILE_LO/SIMFILE_HI, so de-interleave with jtutil drop1, the
# same way cores/shanon carves its road ROM. Verified: road_lo+road_hi reconstruct
# epr-7181 (crc b4740419).
dd if=rom.bin of=road.bin bs=$(( 0x8000 )) count=1 status=none \
   iflag=skip_bytes skip=$(( JTFRAME_HEADER + ROAD_START ))
jtutil drop1 -l < road.bin > road_lo.bin
jtutil drop1    < road.bin > road_hi.bin
rm -f road.bin

# epr-6844 (sprite zoom, ZOOM_START, 0x2000) is a plain 8-bit ROM -- one file.
dd if=rom.bin of=zoom.bin bs=$(( 0x2000 )) count=1 status=none \
   iflag=skip_bytes skip=$(( JTFRAME_HEADER + ZOOM_START ))

if [ ! -s road_lo.bin ] || [ ! -s road_hi.bin ] || [ ! -s zoom.bin ]; then
    echo "road/zoom carve produced an empty file -- check ROAD_START/ZOOM_START"
    exit 1
fi

# Content check, not just non-empty (a shifted ROAD_START/ZOOM_START yields
# full-size GARBAGE, which -s cannot catch). crc32 matches the MRA/MAME ROM CRCs:
# road_lo+road_hi concatenate to epr-7181 (b4740419); each half and the zoom ROM
# have the fixed CRCs below. Same intent as the mcu.bin 0201 reset-vector guard.
check_crc() { # $1 file  $2 expected-hex
    local got
    got=$(python3 -c "import zlib,sys;print('%08x'%(zlib.crc32(open(sys.argv[1],'rb').read())&0xffffffff))" "$1")
    if [ "$got" != "$2" ]; then
        echo "$1 crc32 $got != expected $2 -- wrong ROAD_START/ZOOM_START offset?"
        exit 1
    fi
}
check_crc road_lo.bin 456a289d
check_crc road_hi.bin b80108ab
check_crc zoom.bin    e3ec7bd6

jtsim "$@"
