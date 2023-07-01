#!/bin/bash
# Use sim.sh -DJTFRAME_CHEAT_SCRAMBLE=1234 for encryption

FILES="test.v ../../hdl/cheat/jtframe_cheat_rom.v ../../hdl/ram/jtframe_prom.v"

if which ncverilog; then
    ncverilog $FILES +access+r +nc64bit $*
else
    iverilog $FILES -o simx -DIVERILOG $* && simx -lxt
    rm -f simx
fi
