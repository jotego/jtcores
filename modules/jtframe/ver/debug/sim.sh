#!/bin/bash

iverilog test.v ../../hdl/jtframe_debug.v -o sim \
    -D JTFRAME_WIDTH=160 -D JTFRAME_HEIGHT=152  && sim -lxt
