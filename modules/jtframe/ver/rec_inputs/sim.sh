#!/bin/bash

iverilog test.v ../../hdl/keyboard/jtframe_rec_inputs.v ../../hdl/ram/*.v -s test -o sim && sim -lxt
rm -f sim