#!/bin/bash

iverilog test.v $JTFRAME/hdl/video/jtframe_credits.v \
    $JTFRAME/hdl/ram/jtframe_{dual_ram,ram}.v -o sim && sim -lxt