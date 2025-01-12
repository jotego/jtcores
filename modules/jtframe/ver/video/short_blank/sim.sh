#!/bin/bash

#echo "Redefine the clock with -DSIMULATION_VTIMER_FCLK=6e6"

iverilog test.v $JTFRAME/hdl/video/jtframe_vtimer.v $JTFRAME/hdl/video/jtframe_short_blank.v -o sim -DSIMULATION $* && sim -lxt
