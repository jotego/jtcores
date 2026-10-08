#!/bin/bash

iverilog test.v ../../../hdl/sdram/jtframe_{ram1_1slot,ram_rq}.v -o sim && sim -lxt
rm -f sim