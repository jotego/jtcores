#!/bin/bash

iverilog -g2005-sv test.v yc_out.v ../../../../hdl/video/jtframe_vtimer.v -o sim -D SIMULATION || exit $?
sim -lxt
rm -f sim 