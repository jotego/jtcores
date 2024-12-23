#!/bin/bash

iverilog *.v ../../doc/{k051960,k052109,k051937}*.v ../../doc/cells/*.v -o sim -s test && sim -lxt
rm -f sim