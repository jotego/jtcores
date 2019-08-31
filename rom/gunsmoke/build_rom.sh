#!/bin/bash

CORE=JTGUN

function rom_len {
    echo $(printf "%05Xh" $(du --bytes $CORE.rom | cut -f 1))
}

function dump {
    echo "$1" starts at $(rom_len)
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> $CORE.rom
    done
}

rm -f $CORE.rom
touch $CORE.rom

dump "MAIN        " gs03.09n gs04.10n gs05.12n
dump "SOUND       " gs02.14h
dump "CHAR        " gs01.11f
# Tile map
dump "Tile map    " gs14.11c

# note that SCROLL Z is repeated
# lower bytes
dump "SCROLL X    " gs13.06c gs12.05c
dump "SCROLL Z    " gs11.04c gs10.02c
# upper bytes
dump "SCROLL Y    " gs09.06a gs08.05a
dump "SCROLL Z    " gs07.04a gs06.02a

# lower bytes
dump "Objects ZY  " gs22.06n gs21.04n gs20.03n gs19.01n
# upper bytes
dump "Objects XW  " gs18.06l gs17.04l gs16.03l gs15.01l

# Not in SDRAM:
dump "PROMs       " g-01.03b g-02.04b g-03.05b g-04.09d g-06.14a g-07.15a g-09.09f g-08.08f g-10.02j g-05.01f

echo ROM length $(rom_len)
if [ -e "$JTGNG_ROOT/rom" ]; then
    cp $CORE.rom $JTGNG_ROOT/rom/$CORE.rom
fi
