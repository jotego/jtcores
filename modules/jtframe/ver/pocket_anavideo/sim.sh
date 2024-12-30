#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_vtimer.v ../../hdl/jtframe_sh.v ../../hdl/video/jtframe_scan2x.v ../../hdl/video/jtframe_wirebw.v ../../hdl/clocking/jtframe_sync.v ../../hdl/ram/jtframe_dual_ram.v ../../hdl/ram/jtframe_rpwp_ram.v ../../target/pocket/jtframe_pocket_anavideo.v ../../target/mist/jtframe_mist_video.v ../../target/mist/osd.sv ../../target/mist/rgb2ypbpr.v  ../../target/pocket/yc_out.sv -o sim -D SIMULATION || exit $?
sim -lxt
rm -f sim 