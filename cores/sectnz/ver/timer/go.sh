#!/bin/bash

LAYOUT=5
HOFFSET=0
VOFFSET=0


while [ $# -gt 0 ]; do
    case "$1" in
        -v)
            shift
            VOFFSET=$1;;
        -h)
            shift
            HOFFSET=$1;;
        -l)
            shift
            LAYOUT=$1;;
        -help)
            echo "Usage: go.sh for simulation of layout style 5"
            echo "       -l n layout style n"
            echo "       -h n HOFFSET set to n"
            echo "       -V n VOFFSET set to n"
            exit 0;;
    esac
    shift
done

iverilog test.v old_timer.v $MODULES/jtgng_timer.v $JTFRAME/hdl/video/jtframe_resync.v -o sim \
    -DSIMULATION -DLAYOUT=$LAYOUT -DSIMULATION_TIMER \
    -DHOFFSET=$HOFFSET -DVOFFSET=$VOFFSET \
    && sim -lxt