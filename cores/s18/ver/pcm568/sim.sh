#!/bin/bash

iverilog test.v ../../hdl/jtpcm568*.v -o sim && sim -lxt
rm -f sim
