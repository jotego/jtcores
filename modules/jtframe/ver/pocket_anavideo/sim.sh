#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_vtimer.v ../../hdl/jtframe_sh.v ../../hdl/video/jtframe_scan2x.v ../../hdl/video/jtframe_wirebw.v ../../hdl/clocking/jtframe_sync.v ../../hdl/ram/jtframe_dual_ram.v ../../hdl/ram/jtframe_rpwp_ram.v ../../target/pocket/jtframe_pocket_anavideo.v ../../target/mist/jtframe_mist_video.v ../../target/mist/osd.sv ../../target/mist/rgb2ypbpr.v -o sim -D SIMULATION || exit $?
sim -lxt
rm -f sim 

/home/rpaiva/jtcores/modules/jtframe/hdl/jtframe_sh.v
 #verilator --lint-only /home/rpaiva/jtcores/modules/jtframe/target/pocket/jtframe_pocket_top.v -I /home/rpaiva/jtcores/modules/jtframe/target/pocket/jtframe_pocket.v /home/rpaiva/jtcores/modules/jtframe/target/pocket/jtframe_pocket_base.v /home/rpaiva/jtcores/modules/jtframe/target/pocket/jtframe_pocket_anavideo.v /home/rpaiva/jtcores/modules/jtframe/target/mist/jtframe_mist_video.v /home/rpaiva/jtcores/modules/jtframe/target/mist/osd.sv /home/rpaiva/jtcores/modules/jtframe/hdl/video/jtframe_scan2x.v /home/rpaiva/jtcores/modules/jtframe/target/mist/rgb2ypbpr.v /home/rpaiva/jtcores/modules/jtframe/hdl/video/jtframe_wirebw.v