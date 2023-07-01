#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_{lfbuf*,vtimer}.v ../../hdl/ram/jtframe_*.v \
    -stest -o sim -DSIMULATION && sim -lxt
rm -f sim
