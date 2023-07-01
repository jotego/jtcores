#!/bin/bash

iverilog test.v ../../hdl/keyboard/jt4701.v -DSIMULATION -o sim && sim -lxt
