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
        -h|-help)
            cat <<EOF
makemra.sh creates MRA files for some cores. Optional arguments:
    -rom        create .rom files too using the mra tool
    -core       specify for which core the files will be generated. Valid values
                sf
                trojan
                sarms
                exed
                hige
                rumble
    -h | -help  shows this message
EOF
            exit 1;;
        *)
            echo "ERROR: unknown argument " $MAKEROM
            exit 1;;
    esac
    shift
done

export JTFRAME
OUTDIR=mra

function set_alt {
    ALTDIR=_alternatives/"_$1"
    mkdir -p $OUTDIR/"$ALTDIR"
}

################## Higemaru
if [[ $MAKELIST = all || $MAKELIST == rumble ]]; then
set_alt "The Speed Rumbler"
mame2dip srumbler.xml -outdir $OUTDIR -altfolder "$ALTDIR" \
    -rbf jtrumble \
    -rename char=gfx1 -swapbytes char \
    -rename scr=gfx2 -order-roms scr 4 0 5 1 6 2 7 3 -frac 1 scr 2 \
    -rename obj=gfx3 -order-roms obj 6 4 2 0 7 5 3 1 -frac 1 obj 4 \
    -corebuttons 2 -buttons "Shoot,Exit car"
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

################## Higemaru
if [[ $MAKELIST = all || $MAKELIST == hige ]]; then
mame2dip higemaru.xml -outdir $OUTDIR\
    -rbf jthige \
    -rename char=gfx1 obj=gfx2 \
    -frac obj 2 \
    -swapbytes maincpu \
    -buttons action unused \
    -order-roms obj 1 0 \
    -rmdipsw Unused -4way
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

################## Street Fighter 1
if [[ $MAKELIST = all || $MAKELIST == sf ]]; then
set_alt "Street Fighter"

mame2dip sf.xml -outdir $OUTDIR -altfolder "$ALTDIR"\
    -rbf jtsf \
    -rename scr2=gfx1 scr1=gfx2 obj=gfx3 char=gfx4 maps=tilerom mcu=protcpu? \
    -swapbytes audiocpu audio2 \
    -setword maincpu 16 \
    -ignore proms \
    -frac obj  2 \
    -frac scr1 2 \
    -frac scr2 2 \
    -frac maps 2 \
    -start maps 0xa8000 \
    -order-roms maps 3 2 1 0 \
    -order-roms scr1 4 0 5 1 6 2 7 3 \
    -order-roms scr2 2 0 3 1 \
    -order-roms obj 7 0 8 1 9 2 10 3 11 4 12 5 13 6 \
    -order maincpu audiocpu audio2 maps char scr1 scr2 obj mcu proms \
    -buttons "punch1,punch2,punch3,kick1,kick2,kick3" \
    -dipbase 8 -rmdipsw Unused -rmdipsw Freeze \
    -info mameversion 229 \
    -info category "Beat 'em up"

# Fix DIP names
find $OUTDIR -name "Street Fighter*.mra" -print0 | xargs -0 sed -i "s/Number of Countries Selected/Countries/g"
find $OUTDIR -name "Street Fighter*.mra" -print0 | xargs -0 sed -i "s/Stage Maximum/Stage Max/g"
find $OUTDIR -name "Street Fighter*.mra" -print0 | xargs -0 sed -i "s/Round Time Count/Time/g"
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

################## Exed Exes
# gfx3 = 16x16 tiles
# gfx4 = OBJ
if [[ $MAKELIST = all || $MAKELIST == exed ]]; then
set_alt "Exed Exes"
mame2dip exedexes.xml -outdir $OUTDIR -altfolder "$ALTDIR"\
    -rbf jtexed \
    -frac gfx3 2 \
    -frac gfx4 2
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

############# Trojan
if [[ $MAKELIST = all || $MAKELIST == trojan ]]; then
set_alt "Trojan"
mame2dip trojan.xml -outdir $OUTDIR -altfolder "$ALTDIR"\
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
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

if [ $MAKEROM = 1 ]; then
    for i in Tro*mra 'Tatakai no Banka (Japan).mra'; do
        mra -z /opt/mame "$i"
    done
    for i in Side*mra; do
        mra -z /opt/mame "$i"
    done
    for i in Side*mra; do
        mra -z /opt/mame "$i"
    done
    for i in Street*mra; do
        mra -z /opt/mame "$i"
    done
    if [ -d /media/jtejada/MIST ]; then
        cp *.rom /media/jtejada/MIST
    fi
    mv *.rom ..
if [[ $MAKELIST != all ]]; then exit 0; fi
fi

