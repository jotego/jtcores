#!/bin/bash

GAME=JTGNG.rom

function rom_len {
    echo $(printf "%05Xh" $(du --bytes $GAME | cut -f 1))
}

function dump {
    echo "$1" starts at $(rom_len)
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

dump "MAIN        " gg3.bin gg4.bin gg5.bin
dump "CHAR        " gg1.bin
dump "SOUND       " gg2.bin

# note that SCROLL Y is repeated
# lower bytes
dump "SCROLL X    " gg9.bin gg8.bin
dump "SCROLL Z    " gg7.bin gg6.bin 
# upper bytes
dump "SCROLL Y    " gg11.bin gg10.bin
dump "SCROLL Y    " gg11.bin gg10.bin

# lower bytes
dump "Objects ZY  " gg17.bin gg16.bin gg15.bin gg15.bin
# upper bytes
dump "Objects XW  " gg14.bin gg13.bin gg12.bin gg12.bin

echo ROM length $(rom_len)
cp $GAME $JTGNG_ROOT/rom/$GAME
echo MD5 Sum: $(md5sum $GAME)
