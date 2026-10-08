#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_{lfbuf*,vtimer}.v ../../hdl/ram/jtframe_*.v \
    ../../target/mister/hdl/jtframe_mr_ddrmux.v \
    -stest -o sim -DSIMULATION -DJTFRAME_LF_BUFFER -DJTFRAME_MR_DDRLOAD && sim -lxt
rm -f sim
