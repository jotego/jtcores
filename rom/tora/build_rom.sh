#!/bin/bash

function rom_len {
    echo $(printf "%05X" $(du --bytes JTTORA.rom | cut -f 1))
}

function dump {
    printf "%-22s = 22'h%s;\n" "$1" "$(rom_len)"
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> JTTORA.rom
    done
}

rm -f JTTORA.rom
touch JTTORA.rom

dump "localparam MAIN0_ADDR" tre_02.6j
dump "localparam MAIN1_ADDR" tre_04.6k
dump "localparam SND_ADDR"   tru_05.12k
dump "localparam SND2_ADDR"  tru_05.12k tru_05.12k # dummy for 2nd sound CPU
dump "localparam CHAR_ADDR"  tr_01.10d
dump "localparam MAP_ADDR"   tr_13.7l tr_13.7l # duplicated to round up

# Scroll
echo // Scroll
# lower bytes
dump "localparam SCRZW_ADDR" tr-03a.2f tr-06a.2h tr-07a.2j tr_08.2l
# upper bytes
dump "localparam SCRXY_ADDR" tr-01a.3f tr-04a.3h tr-02a.3j tr-05.3l
## Objects
echo // even words
    # lower bytes
    dump "localparam OBJWZ_ADDR0" tr-12a.2d
    # upper bytes
    dump "localparam OBJXY_ADDR0" tr-11a.3d
echo // odd words
    # lower bytes
    dump "localparam OBJWZ_ADDR1" tr-10a.2b
    # upper bytes
    dump "localparam OBJXY_ADDR1" tr-09a.3b

# Not in SDRAM:
echo // FPGA BRAM:
dump "localparam PROM_ADDR" tr.9e

echo // ROM length $(rom_len)
cp JTTORA.rom $JTGNG/rom/JTTORA.rom
