#!/bin/bash

iverilog test.v ../../hdl/sound/*.v -m test -o sim && sim -lxt
