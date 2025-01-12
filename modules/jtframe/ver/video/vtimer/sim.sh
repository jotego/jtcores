#!/bin/bash

echo "Redefine the clock with -DSIMULATION_VTIMER_FCLK=6e6"

iverilog test.v ../../../hdl/video/jtframe_vtimer.v -o sim -DSIMULATION $* && sim -lxt