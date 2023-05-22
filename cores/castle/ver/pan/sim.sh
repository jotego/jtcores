#!/bin/bash

iverilog pan.v -o sim && sim -lxt
rm -f sim
