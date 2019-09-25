#!/bin/bash

function rom_len {
    echo $(printf "%05X" $(du --bytes JTBIOCOM.rom | cut -f 1))
}

function dump {
    printf "%-22s = 22'h%s;\n" "$1" "$(rom_len)"
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

dump "localparam MAIN0_ADDR" tse_02.1a tse_03.2a
dump "localparam MAIN1_ADDR" tse_04.1b tse_05.2b
dump "localparam SND_ADDR" ts_01b.4e
dump "localparam CHAR_ADDR" tsu_08.8l

# Scroll 1
echo // Scroll 1/2
# lower bytes
dump "localparam SCR1XY_ADDR" ts_12.17f ts_11.15f ts_17.17g ts_16.15g
# SCR2 repeated to keep all 16-bit of address zero
dump "localparam SCR2XY_ADDR" tsu_07.5l tsu_07.5l
# upper bytes
dump "localparam SCR1ZW_ADDR" ts_13.18f ts_18.18g ts_23.18j ts_24.18k
dump "localparam SCR2ZW_ADDR" tsu_06.4l tsu_06.4l

# lower bytes
dump "localparam OBJZ_ADDR" tse_10.13f tsu_09.11f tse_15.13g tsu_14.11g
# upper bytes
dump "localparam OBJX_ADDR" tse_20.13j tsu_19.11j tse_22.17j tsu_21.15j

# Not in SDRAM:
dump "localparam MCU_ADDR" ts.2f
dump "localparam PROM_ADDR" 63s141.18f

echo // ROM length $(rom_len)
cp JTBIOCOM.rom $JTGNG_ROOT/rom/JTBIOCOM.rom
