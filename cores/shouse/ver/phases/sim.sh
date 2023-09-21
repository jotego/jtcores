#!/bin/bash

iverilog test.v -o sim || exit $?
sim -lxt
rm -f sim