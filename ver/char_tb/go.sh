#!/bin/bash

echo Press q to exit the character preview
echo use a very low size font on the terminal
echo to see the characters

iverilog char_tb.v \
	../../hdl/jt_gng_a5.v ../../hdl/jt_gng_a6.v ../../hdl/jt_gng_a7.v \
	../../hdl/jt74.v ../../hdl/M58725.v -s char_tb -o sim \
&& sim -lxt | less -S