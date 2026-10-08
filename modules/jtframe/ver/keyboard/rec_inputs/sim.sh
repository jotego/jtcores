#!/bin/bash

iverilog test.v $JTFRAME/hdl/keyboard/jtframe_rec_inputs.v $JTFRAME/hdl/ram/*.v -s test -o sim && sim -lxt
rm -f sim