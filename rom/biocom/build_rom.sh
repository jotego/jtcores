#!/bin/bash

function rom_len {
    echo $(printf "%05Xh" $(du --bytes JTBIOCOM.rom | cut -f 1))
}

function dump {
    echo "$1" starts at $(rom_len)
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> JTBIOCOM.rom
    done
}

rm -f JTBIOCOM.rom
touch JTBIOCOM.rom

dump "MAIN even   " tse_02.1a tse_03.2a
dump "MAIN odd    " tse_04.1b tse_05.2b
dump "SOUND       " ts_01b.4e
dump "MCU         " ts.2f
dump "CHAR        " tsu_08.8l

# Scroll 1
# lower bytes
dump "SCROLL XY   " ts_12.17f ts_11.15f ts_17.17g ts_16.15g
# upper bytes
dump "SCROLL ZW   " ts_13.18f ts_18.18g ts_23.18j ts_24.18k

# Scroll 2
# lower bytes
dump "SCROLL XY   " tsu_07.5l
# upper bytes
dump "SCROLL ZW   " tsu_06.4l

# lower bytes
dump "Objects ZY  " tse_10.13f tsu_09.11f tse_15.13g tsu_14.11g
# upper bytes
dump "Objects XW  " tse_20.13j tsu_19.11j tse_22.17j tsu_21.15j

# Not in SDRAM:
dump "PROMs       " 63s141.18f

echo ROM length $(rom_len)
cp JTBIOCOM.rom $JTGNG_ROOT/rom/JTBIOCOM.rom
