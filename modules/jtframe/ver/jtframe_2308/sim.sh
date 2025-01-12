#!/bin/bash

FILES="test.v ../../hdl/mister/jtframe_2308.v"

if which ncverilog; then
    ncverilog $FILES +access+r +define+NCVERILOG
else
    iverilog $FILES -o sim && sim -fst
fi

