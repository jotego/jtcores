#!/bin/bash
# gfx1 CHAR
# gfx2 SCR1
# gfx3 OBJ
# gfx4 SCR2
# gfx5 map ROM for SCR2

MAKEROM=0
MAKELIST=all

while [ $# -gt 0 ]; do
    case $1 in
        -rom)
            MAKEROM=1;;
        -core)
            shift
            MAKELIST=$1;;
        *)
            echo "ERROR: unknown argument " $MAKEROM
            exit 1;;
    esac
    shift
done

export JTFRAME
(cd $JTFRAME/cc;make) || exit $?

################## Side Arms
# gfx2 = 32x32 tiles
# gfx3 = OBJ
if [[ $MAKELIST = all || $MAKELIST == sarms ]]; then
mame2dip sidearms.xml \
    -rbf jtsarms \
    -frac gfx2 2 \
    -frac gfx3 2 \
    -swapbytes audiocpu \
    -swapbytes maincpu \
    -rmdipsw Freeze \
    -buttons "fire-left" "fire-right" "option"
#    -order-roms gfx2  4 5 6 7 0 1 2 3
fi

################## Exed Exes
# gfx3 = 16x16 tiles
# gfx4 = OBJ
if [[ $MAKELIST = all || $MAKELIST == exed ]]; then
mame2dip exedexes.xml \
    -rbf jtexed \
    -frac gfx3 2 \
    -frac gfx4 2
fi

############# Trojan
if [[ $MAKELIST = all || $MAKELIST == trojan ]]; then
mame2dip trojan.xml \
    -rbf jttrojan \
    -frac gfx2 4 \
    -frac gfx3 2 \
    -frac gfx4 2 \
    -swapbytes gfx5 \
    -start gfx1 0x40000 \
    -order maincpu soundcpu adpcm gfx5 gfx4 gfx1 gfx2 gfx3 \
    -order-roms maincpu 1 2 0 \
    -order-roms gfx2  6 7 4 5 2 3 0 1\
    -header 32 -header-data 2 \
    -header-offset 8 soundcpu gfx1 gfx2 gfx3 proms
fi

if [ $MAKEROM = 1 ]; then
    for i in Tro*mra 'Tatakai no Banka (Japan).mra'; do
        mra -z /opt/mame "$i"
    done
    for i in Side*mra; do
        mra -z /opt/mame "$i"
    done

    if [ -d /media/jtejada/MIST ]; then
        cp *.rom /media/jtejada/MIST
    fi
    mv *.rom ..
fi

mkdir -p _alternatives/_Trojan
mkdir -p _alternatives/_Side\ Arms
mv 'Trojan (bootleg).mra' 'Trojan (US set 1).mra' 'Trojan (US set 2).mra' 'Tatakai no Banka (Japan).mra' _alternatives/_Trojan 2> /dev/null
mv Side*US*.mra Side*Japan*.mra _alternatives/_Side\ Arms  2> /dev/null

