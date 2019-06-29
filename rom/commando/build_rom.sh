#!/bin/bash

function rom_len {
    echo $(printf "%05Xh" $(du --bytes jtcommando.rom | cut -f 1))
}

function dump {
    echo "$1" starts at $(rom_len)
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> jtcommando.rom
    done
}

rm -f jtcommando.rom
touch jtcommando.rom

dump "MAIN        " cm04.9m cm03.8m
dump "SOUND       " cm02.9f
dump "CHAR        " vt01.5d
# lower bytes
# note that SCROLL Z and PROMs are repeated
dump "SCROLL X    " vt11.5a vt12.6a vt15.9a
dump "SCROLL Z    " vt15.9a vt16.10a
dump "Objects ZY  " vt05.7e vt06.8e vt07.9e
# upper bytes
dump "SCROLL Y    " vt13.7a vt14.8a
dump "SCROLL Z    " vt15.9a vt16.10a
dump "Objects XW  " vt08.7h vt09.8h vt10.9h
# Not in SDRAM:
dump "PROMs       " vtb1.1d vtb2.2d vtb3.3d vtb4.1h vtb5.6l vtb6.6e

echo ROM length $(rom_len)
