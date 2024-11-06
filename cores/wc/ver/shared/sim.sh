#!/bin/bash -e
echo "ERROR: compilation error" > sim.log
iverilog -g2012 test.v ../../hdl/jtwc_shared.v -o sim -DSIMULATION && sim -lxt | tee sim.log
rm -f sim
if grep ERROR sim.log; then
	echo FAIL
	exit 1
else
	echo PASS
fi
