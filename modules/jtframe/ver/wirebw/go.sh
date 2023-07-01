#!/bin/bash

iverilog ../../hdl/jtframe_sh.v ../../hdl/video/jtframe_wirebw.v test.v -s test -o sim && sim -lxt
