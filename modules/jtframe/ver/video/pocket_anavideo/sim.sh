#!/bin/bash -e

HDL=$JTFRAME/hdl
MIST=$JTFRAME/target/mist
POCKET=$JTFRAME/target/pocket

iverilog test.v $HDL/video/jtframe_vtimer.v $HDL/jtframe_sh.v \
	$HDL/video/jtframe_scan2x.v $HDL/video/jtframe_wirebw.v \
	$HDL/clocking/jtframe_sync.v $HDL/ram/jtframe_dual_ram.v \
	$HDL/ram/jtframe_rpwp_ram.v \
	$MIST/hdl/{jtframe_mist_video.v,osd.sv,rgb2ypbpr.v} \
	$POCKET/hdl/{jtframe_pocket_anavideo.v,yc_out.sv} -o sim -D SIMULATION
sim -lxt
rm -f sim 