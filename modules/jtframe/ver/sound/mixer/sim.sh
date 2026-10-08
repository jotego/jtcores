#!/bin/bash
HDL=../../../hdl
if which ncverilog; then
    ncverilog test.v  +access+r $HDL/sound/jtframe_mixer.v +define+NCVERILOG
else
    iverilog test.v  $HDL/sound/jtframe_mixer.v -o sim -s test && sim -lxt
fi