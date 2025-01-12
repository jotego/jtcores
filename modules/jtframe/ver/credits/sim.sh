#!/bin/bash

iverilog test.v ../../hdl/video/jtframe_credits.v \
    ../../hdl/ram/jtframe_{dual_ram,ram}.v -o sim && sim -lxt