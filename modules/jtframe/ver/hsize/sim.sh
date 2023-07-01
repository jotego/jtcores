#!/bin/bash
iverilog test.v ../../hdl/{video/jtframe_hsize.v,video/jtframe_vtimer.v,ram/jtframe_dual_ram.v} \
    -o sim -D SIMULATION || exit $?
sim -lxt
rm -f sim