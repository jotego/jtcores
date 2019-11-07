#!/bin/bash

DUMP=
echo "" > trace.h

while [ $# -gt 0 ]; do
    case "$1" in
        -w)
            DUMP=--trace
            echo "#define TRACE" > trace.h;;
        *)  
            echo "ERROR: Unknown argument " $1
            exit 1;;
    esac
    shift
done

verilator test.v -F $JTGNG/modules/jtgng_obj.f $JTGNG/modules/jtgng_{timer,cen}.v \
    --cc --exe test.cpp --top-module test $DUMP || exit $?
make -j -C obj_dir -f Vtest.mk Vtest || exit $?

date
echo simulating
if [ "$DUMP" = "" ]; then
    obj_dir/Vtest
else
    obj_dir/Vtest -w >(vcd2fst -v - -f test.fst)
fi
echo done
date

# exit 1

rm obj_*.jpg
for i in obj*.raw; do
    echo $i
    convert -resize 300%x300% \
            -size 256x224 -depth 8 RGBA:$i \
            $(basename $i .raw).jpg \
    && rm $i
done