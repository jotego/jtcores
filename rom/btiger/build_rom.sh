#!/bin/bash

function rom_len {
    echo $(printf "%05X" $(du --bytes JTBTIGER.rom | cut -f 1))
}

function dump {
    printf "%-22s = 22'h%s;\n" "$1" "$(rom_len)"
    shift
    for i in $*; do
        if [ ! -e $i ]; then
            echo cannot find file $i
            exit 1
        fi
        cat $i >> JTBTIGER.rom
    done
}

rm -f JTBTIGER.rom
touch JTBTIGER.rom

dump "localparam BANK_ADDR"  bdu-02a.6e bdu-03a.8e bd-04.9e bd-05.10e
dump "localparam MAIN_ADDR"  bdu-01a.5e
dump "localparam SND_ADDR"   bd-06.1l
dump "localparam CHAR_ADDR"  bd-15.2n bd-15.2n

# Scroll
echo // Scroll
# lower bytes
dump "localparam SCRZW_ADDR"  bd-12.5b bd-11.4b 
# upper bytes
dump "localparam SCRXY_ADDR" bd-14.9b bd-13.8b
## Objects
echo // objects
    # lower bytes
    dump "localparam OBJWZ_ADDR"  bd-08.5a bd-07.4a
    # upper bytes
    dump "localparam OBJXY_ADDR"  bd-10.9a bd-09.8a

# Not in SDRAM:
echo // FPGA BRAM:
dump "localparam MCU_ADDR"  bd.6k
dump "localparam PROM_ADDR" bd01.8j bd02.9j bd03.11k bd04.11l

echo // ROM length $(rom_len)
cp JTBTIGER.rom $JTGNG/rom/JTBTIGER.rom
