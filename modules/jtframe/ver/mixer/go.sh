#!/bin/bash

if which ncverilog; then
    ncverilog test.v  +access+r ../../hdl/sound/jtframe_mixer.v +define+NCVERILOG
else
    iverilog test.v  ../../hdl/sound/jtframe_mixer.v -o sim -s test && sim -lxt
fi