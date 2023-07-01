#!/bin/bash

iverilog test.v ../../hdl/keyboard/jt{4701,frame_dial}.v -o sim -s test && sim -lxt
