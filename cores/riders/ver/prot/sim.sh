#!/bin/bash
iverilog test.v -o sim && sim -lxt
rm -f sim