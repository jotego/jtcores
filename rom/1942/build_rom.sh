#!/bin/bash

GAME=JT1942.rom

function rom_len {
    echo $(printf "%05Xh" $(du --bytes $GAME | cut -f 1))
}

function dump {
    echo "$1"$(rom_len)\;
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> $GAME
    done
}

rm -f $GAME
touch $GAME

dump "parameter [21:0] MAIN_ADDR  = 22'" srb-03.m3 srb-04.m4 srb-05.m5 srb-06.m6 srb-06.m6 srb-07.m7
dump "parameter [21:0] SOUND_ADDR = 22'" sr-01.c11
dump "parameter [21:0] CHAR_ADDR  = 22'" sr-02.f2

# note that SCROLL Y is repeated
# lower bytes
dump "SCROLL X    " sr-10.a3 sr-11.a4
dump "SCROLL Z    " sr-08.a1 sr-09.a2
# upper bytes
dump "SCROLL Y    " sr-12.a5 sr-13.a6
dump "SCROLL Y    " sr-12.a5 sr-13.a6

# lower bytes
dump "Objects ZY  " sr-14.l1 sr-16.n1
# upper bytes
dump "Objects XW  " sr-15.l2 sr-17.n2
# PROMs
dump "PROMs" sb-1.k6 sb-2.d1  sb-3.d2 sb-4.d6 sb-5.e8 \
             sb-6.e9 sb-7.e10 sb-0.f1 sb-8.k3 sb-9.m11

echo ROM length $(rom_len)
cp $GAME $JTGNG/rom/$GAME
echo MD5 Sum: $(md5sum $GAME)
