#!/bin/bash
HDL=../../../hdl
iverilog $HDL/jtframe_sh.v $HDL/video/jtframe_wirebw.v test.v -s test -o sim && sim -lxt
