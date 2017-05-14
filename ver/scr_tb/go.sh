#!/bin/bash

echo Press q to exit the character preview
echo use a very low size font on the terminal
echo to see the characters

iverilog scr_tb.v \
	../../hdl/jt_gng_a5.v ../../hdl/jt_gng_b7.v ../../hdl/jt_gng_b8.v  ../../hdl/jt_gng_b9.v \
	../../hdl/jt74.v ../../hdl/M58725.v -s scr_tb -DSCR_TEST -o sim \
&& sim -lxt | less -S