#!/bin/bash

DUMP=
CODE=30
CMDONLY=

if ! which ncverilog; then
    MACRO=-D
else
    MACRO=+define+
fi

while [ $# -gt 0 ]; do
    case $1 in
        -w) DUMP=${MACRO}DUMP;;
        -c) shift; CODE=${MACRO}CODE=8\'h$1;;
        -t) CMDONLY="echo ";;
        *) echo "Unknown argument $1"; exit 1;;
    esac
    shift
done

function add_dir {
    if [ ! -d "$1" ]; then
        echo "ERROR: add_dir (sim.sh) failed because $1 is not a directory"
        exit 1
    fi
    for i in $(cat $1/$2); do
        if [ "$i" = "-sv" ]; then 
            # ignore statements that iVerilog cannot understand
            continue; 
        fi
        fn="$1/$i"
        if [ ! -e "$fn" ]; then
            (>&2 echo "Cannot find file $fn")
            exit 1
        fi
        echo $fn
    done
}

if ! which ncverilog; then
    $CMDONLY iverilog -f gather.f \
        $(add_dir $JTGNG/modules/jt12/hdl jt03.f) \
        $(add_dir $JTGNG/modules/jtframe/hdl/cpu/tv80 tv80.f) \
        test.v -s test \
        -o sim -DSIMULATION $DUMP $CODE && sim -lxt
else
    $CMDONLY ncverilog test.v -F gather.f -F $JTGNG/modules/jt12/hdl/jt03.f \
        -F $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80.f \
        +access+r +nc64bit +define+NCVERILOG \
        +define+SIMULATION $DUMP $CODE
fi

if [ -e fm_sound.raw ]; then
    raw2wav -s 49721 < fm_sound.raw && rm fm_sound.raw
fi
