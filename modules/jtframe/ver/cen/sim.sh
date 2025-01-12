#!/bin/bash

iverilog test.v ../../hdl/clocking/jtframe_{cen48,cen24,frac_cen}.v -o sim -s test -DSIMULATION && sim -lxt
