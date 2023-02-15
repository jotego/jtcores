#!/bin/bash
TOP=jts16_fd1094_dec

verilator ../../hdl/$TOP.v $JTFRAME/hdl/ram/jtframe_prom.v \
	-cc test.cpp fd1094.cpp -exe --top-module $TOP -DSIMULATION -DDEBUG
export CPPFLAGS="$CPPFLAGS -O3"

if ! make -j -C obj_dir -f V${TOP}.mk V${TOP} > make.log; then
    cat make.log
    exit $?
else
    rm make.log
fi

obj_dir/V$TOP
