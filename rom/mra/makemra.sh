#!/bin/bash
# gfx1 CHAR
# gfx2 SCR1
# gfx3 OBJ
# gfx4 SCR2
# gfx5 map ROM for SCR2

export JTFRAME
(cd $JTFRAME/cc;make) || exit $?

mame2dip trojan.xml \
    -rbf jttrojan \
    -frac gfx2 4 \
    -frac gfx3 2 \
    -frac gfx4 2 \
    -start gfx1 0x30000 \
    -order maincpu soundcpu adpcm gfx5 gfx1 gfx2 gfx4 gfx3 \
    -order-roms maincpu 1 2 0 \
    -order-roms gfx2 0 1 2 3 4 5 6 7 \
    -header 32 -header-data 2 \
    -header-offset 8 soundcpu gfx1 gfx2 gfx3 proms

for i in Tro*mra 'Tatakai no Banka (Japan).mra'; do
    mra -z /opt/mame "$i"
done

# mkdir -p _alternatives/_Trojan
# mv 'Trojan (bootleg).mra' 'Trojan (US set 1).mra' 'Trojan (US set 2).mra' 'Tatakai no Banka (Japan).mra' _alternatives/_Trojan
#
# if [ -d /media/jtejada/MIST ]; then
#     cp *.rom /media/jtejada/MIST
# fi

mv *.rom ..