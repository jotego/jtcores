#!/bin/bash -e
for i in 1 2 8 9;do
	iverilog -g2012 ../../hdl/*.v test.v -o sim$i -DSINGLE=$i -DSIMULATION -DJTFRAME_MCLK=48000000
	nice sim$i &
done
wait
rm -f sim*
