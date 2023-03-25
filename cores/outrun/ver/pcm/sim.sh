#!/bin/bash

iverilog -D SIMULATION  \
    test.v ../../hdl/jtoutrun_pcm.v $JTFRAME/hdl/ram/*.v \
    $CORES/s16/hdl/jts16_cen.v $JTFRAME/hdl/clocking/*.v \
    -s test -o sim || exit $?
sim -lxt
rm -f sim