#!/bin/bash

verilator test.v -F $JTGNG/modules/jtgng_obj.f $JTGNG/modules/jtgng_{timer,cen}.v \
    --cc --exe test.cpp --top-module test || exit $?
make -j -C obj_dir -f Vtest.mk Vtest || exit $?

date
echo simulating
obj_dir/Vtest
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