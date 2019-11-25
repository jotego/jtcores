#!/bin/bash

DUMP=
EXTRA=
CMDONLY=
DEFS=
echo "" > trace.h

while [ $# -gt 0 ]; do
    case $1 in
        -w)
            DUMP=--trace
            echo "#define TRACE" > trace.h;;
        -nofm)
            echo "Skipping FM/PSG sound simulation"
            DEFS="$DEFS -DNOFM -DNOSSG";;
        :)
            shift
            EXTRA="$*"
            break;;
        -test) CMDONLY="echo ";;
        *) echo "Unknown argument $1"; exit 1;;
    esac
    shift
done

$CMDONLY verilator -DTV80S $DEFS -f gather.f \
    -F $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80.f \
    -F $JTGNG/modules/jt5205/hdl/jt5205.f \
    test_verilator.v --top-module test \
    --cc --exe test.cpp $DUMP \
    --cc ../../../modules/jtframe/cc/WaveWritter.cpp \
    || exit $?

make -j -C obj_dir -f Vtest.mk Vtest || exit $?

date
echo simulating
if [ "$DUMP" = "" ]; then
    obj_dir/Vtest $EXTRA
else
    obj_dir/Vtest $EXTRA -w >(vcd2fst -v - -f test.fst)
fi
echo done

date