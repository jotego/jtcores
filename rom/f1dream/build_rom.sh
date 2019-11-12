#!/bin/bash

function rom_len {
    echo $(printf "%05X" $(du --bytes JTF1DREAM.rom | cut -f 1))
}

function dump {
    printf "%-22s = 22'h%s;\n" "$1" "$(rom_len)"
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> JTF1DREAM.rom
    done
}

rm -f JTF1DREAM.rom
touch JTF1DREAM.rom

dump "localparam MAIN0_ADDR" 06j_02.bin
dump "localparam MAIN1_ADDR" 06k_03.bin
dump "localparam SND_ADDR"   12k_04.bin
dump "localparam DUMMY"      12k_04.bin 12k_04.bin
dump "localparam CHAR_ADDR"  10d_01.bin
dump "localparam MAP_ADDR"   07l_15.bin 07l_15.bin # duplicated to round up

# Scroll
echo // Scroll
# lower bytes
dump "localparam SCRZW_ADDR" 02f_11.bin 17f_09.bin 02h_13.bin 02h_13.bin 
dump "// repetition        " 02f_11.bin 17f_09.bin 02h_13.bin 02h_13.bin 
# upper bytes
dump "localparam SCRXY_ADDR" 03f_12.bin 01f_10.bin 03h_14.bin 03h_14.bin 
dump "// repetition        " 03f_12.bin 01f_10.bin 03h_14.bin 03h_14.bin 
## Objects
echo // even words
    # lower bytes
    dump "localparam OBJWZ_ADDR0" 02d_07.bin 02d_07.bin
    # upper bytes
    dump "localparam OBJXY_ADDR0" 03d_08.bin 03d_08.bin
echo // odd words
    # lower bytes
    dump "localparam OBJWZ_ADDR1" 02b_05.bin 02b_05.bin
    # upper bytes
    dump "localparam OBJXY_ADDR1" 03b_06.bin 03b_06.bin

# Not in SDRAM:
echo // FPGA BRAM:
dump "localparam PROM_ADDR" 09e_tr.bin
dump "// repetition       " 09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin \
    09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin \
    09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin 09e_tr.bin 
dump "localparam MCU_ADDR" 8751.mcu

echo // ROM length $(rom_len)
cp JTF1DREAM.rom $JTGNG/rom/JTF1DREAM.rom
