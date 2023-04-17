#!/bin/bash

iverilog test.v ../../doc/k051962*.v ../../doc/cells/*.v -o sim -s test && sim -lxt
rm -f sim