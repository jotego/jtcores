#!/bin/bash

iverilog jt_gng_a5_tb.v ../../hdl/jt_gng_a5.v ../../hdl/jt74.v -o sim && sim -lxt