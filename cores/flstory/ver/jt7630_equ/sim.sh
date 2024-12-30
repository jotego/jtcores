#!/bin/bash -e
# clear
# echo "> $0 $*"
TOP=jt7630_equ

verilator ../../hdl/jt7630_equ.v $JTFRAME/hdl/sound/jtframe_{hipass,pole,limsum,limmul}.v -cc test.cc -exe --trace -GDCRM=0

if ! make -j -C obj_dir -f V${TOP}.mk V${TOP} > make.log; then
    cat make.log
    exit $?
else
    rm make.log
fi

obj_dir/V$TOP $*
if [ -e test.vcd ]; then
    echo vcd to fst conversion...
    vcd2fst test.vcd test.fst
    rm -f test.vcd
    echo done
fi