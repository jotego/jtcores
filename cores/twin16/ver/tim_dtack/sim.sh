#!/bin/bash -e

iverilog ../../hdl/jttwin16_{dtack,share}.v test.v \
	$JTFRAME/hdl/jtframe_bcd_cnt.v \
	$JTFRAME/hdl/clocking/jtframe_{gated_cen,freqinfo}.v \
	$JTFRAME/hdl/ram/jtframe_{ram,ram16,dual_ram16,dual_ram}.v \
	-D JTFRAME_MCLK=49152000 -o sim
sim -lxt
rm -f sim