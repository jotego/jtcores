#!/bin/bash

iverilog test.v ../../hdl/jtdd_timing.v ../../modules/jtframe/hdl/clocking/jtframe_cen48.v \
    -s test -o sim && sim -lxt
