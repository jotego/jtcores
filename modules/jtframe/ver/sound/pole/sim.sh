#!/bin/bash -e

trap "rm -f test.vcd" INT KILL

TOP=test
HDL=../../../hdl

rm -f test.vcd
mkfifo test.vcd
vcd2fst -v test.vcd -f test.fst&
verilator test.v $HDL/sound/jtframe_pole.v -cc test.cc -exe --trace -GWS=16 -GWA=15

if ! make -j -C obj_dir -f V${TOP}.mk V${TOP} > make.log; then
    cat make.log
    exit $?
fi

rm -f make.log
obj_dir/V$TOP $*
rm -f test.vcd
