#!/bin/bash


#while [ $# -gt 0 ]; do
#    case "$1" in
#        -v)
#            shift
#            VOFFSET=$1;;
#        -h)
#            shift
#            HOFFSET=$1;;
#        -l)
#            shift
#            LAYOUT=$1;;
#        -help)
#            echo "Usage: go.sh for simulation of layout style 5"
#            echo "       -l n layout style n"
#            echo "       -h n HOFFSET set to n"
#            echo "       -V n VOFFSET set to n"
#            exit 0;;
#    esac
#    shift
#done

iverilog test.v $MODULES/jtgng_objdma.v $JTFRAME/hdl/clocking/jtframe_cencross_strobe.v \
    $MODULES/jtgng_dual_ram.v \
    -o sim \
    -DSIMULATION \
    && sim -lxt