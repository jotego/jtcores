#!/bin/bash
iverilog -g2012 ../../hdl/*.v test.v -o sim -DSIMULATION -DJTFRAME_MCLK=48000000 && sim -lxt
rm -f sim
