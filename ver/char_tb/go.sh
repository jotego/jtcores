#!/bin/bash

iverilog char_tb.v \
	../../hdl/jt_gng_a5.v ../../hdl/jt_gng_a6.v ../../hdl/jt_gng_a7.v \
	../../hdl/jt74.v ../../hdl/M58725.v -s char_tb -o sim && sim -lxt