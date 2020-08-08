#!/bin/bash

if [ ! -e 63s141.15h ]; then
    echo "ERROR: missing file 63s141.15h from Side Arms"
    exit 1;
fi

if [ ! -e 63s141.16h ]; then
    echo "ERROR: missing file 63s141.16h from Side Arms"
    exit 1;
fi

iverilog test.v $JTFRAME/hdl/video/jtframe_vtimer.v -o sim -DSIMULATION && sim -lxt
