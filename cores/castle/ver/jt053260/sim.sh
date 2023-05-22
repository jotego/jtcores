#!/bin/bash

iverilog  -o sim ../../hdl/jtk053260.v test.v -DSIMULATION && sim -lxt
rm -f sim

