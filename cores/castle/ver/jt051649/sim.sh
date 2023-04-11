#!/bin/bash

iverilog test.v ../../hdl/jt051649.v $JTFRAME/hdl/ram/jtframe_dual_ram.v \
    -DSIMULATION -s test -o sim && sim -lxt
rm -f sim
