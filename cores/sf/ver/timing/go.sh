#!/bin/bash

if [ ! -e mb7114h.12j ]; then
    echo "ERROR: missing file mb7114h.12j from Street Fighter"
    exit 1;
fi

if [ ! -e mb7114h.12k ]; then
    echo "ERROR: missing file mb7114h.12k from Street Fighter"
    exit 1;
fi

iverilog test.v $JTFRAME/hdl/video/jtframe_vtimer.v -o sim -DSIMULATION && sim -lxt
