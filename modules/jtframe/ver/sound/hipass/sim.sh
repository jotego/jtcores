#!/bin/bash

TOP=jtframe_hipass

verilator $JTFRAME/hdl/sound/jtframe_hipass.v -cc test.cc -exe --trace -GWS=16 -GWA=14

if ! make -j -C obj_dir -f V${TOP}.mk V${TOP} > make.log; then
    cat make.log
    exit $?
else
    rm make.log
fi

obj_dir/V$TOP
