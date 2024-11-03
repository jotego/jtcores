#!/bin/bash
iverilog -g2012 test.v ../../hdl/jtwc_shared.v -o sim -DSIMULATION && sim -lxt | tee sim.log
rm -f sim
if grep ERROR sim.log; then
	echo FAIL
else
	echo PASS
fi
