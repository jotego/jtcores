#!/bin/bash

LAYOUT=5

while [ $# -gt 0 ]; do
    case "$1" in
        -help)
            echo "Usage: go.sh for simulation of layout style 5"
            echo "       go.sh n for layout style n"
            exit 0;;
        *)
            LAYOUT=$1
            break;;
    esac
done

iverilog test.v old_timer.v $MODULES/jtgng_timer.v -o sim \
    -D SIMULATION -D LAYOUT=$LAYOUT \
    && sim -lxt