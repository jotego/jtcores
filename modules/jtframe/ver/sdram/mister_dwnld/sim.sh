#!/bin/bash

iverilog test.v ../../../hdl/{mister/jtframe_mister_dwnld,ram/jtframe_dual_ram}.v -o sim || exit $?
sim -lxt