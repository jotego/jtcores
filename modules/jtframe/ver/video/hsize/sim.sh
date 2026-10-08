#!/bin/bash

iverilog test.v $JTFRAME/hdl/{video/jtframe_hsize.v,video/jtframe_vtimer.v,ram/jtframe_dual_ram.v,ram/jtframe_rpwp_ram.v,video/jtframe_linebuf.v} \

    -o sim -D SIMULATION || exit $?
sim -lxt
rm -f sim 