#!/bin/bash

function rom_len {
    echo $(printf "%05Xh" $(du --bytes JTVULGUS.rom | cut -f 1))
}

function dump {
    echo "$1" starts at $(rom_len)
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> JTVULGUS.rom
    done
}

rm -f JTVULGUS.rom
touch JTVULGUS.rom

dump "MAIN        " vulgus.002 vulgus.003 vulgus.004 vulgus.005 1-8n.bin 
echo repeating main
dump "      repeat" vulgus.002 vulgus.003 vulgus.004 vulgus.005 1-8n.bin
dump "SOUND       " 1-11c.bin 1-11c.bin
dump "CHAR        " 1-3d.bin

# note that SCROLL Z is repeated
# lower bytes
dump "SCROLL Z    " 2-4a.bin 2-5a.bin
dump "SCROLL X    " 2-2a.bin 2-3a.bin
# upper bytes
dump "SCROLL Y    " 2-6a.bin 2-7a.bin
dump "SCROLL Y    " 2-6a.bin 2-7a.bin


# lower bytes
dump "Objects XW  " 2-4n.bin 2-5n.bin
dump "    repeat  " 2-2n.bin 2-3n.bin
# upper bytes
dump "Objects ZY  " 2-2n.bin 2-3n.bin
dump "    repeat  " 2-4n.bin 2-5n.bin
# Not in SDRAM:
#  0    1   2  3    4  5  6   7   8     9
# IRQ  c9.bin x 3   R  G  B CHAR OBJ  Timing
dump "PROMs       " 82s126.9k c9.bin c9.bin c9.bin e8.bin e9.bin e10.bin d1.bin j2.bin 82s129.8n

echo ROM length $(rom_len)
cp JTVULGUS.rom $JTGNG_ROOT/rom/JTVULGUS.rom
