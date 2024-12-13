#!/bin/bash

TOP=jtframe_zero

verilator ../../hdl/sound/jtframe_zero.v -cc test.cc -exe --trace -GWS=16 -GWA=12

if ! make -j -C obj_dir -f V${TOP}.mk V${TOP} > make.log; then
    cat make.log
    exit $?
else
    rm make.log
fi

obj_dir/V$TOP
