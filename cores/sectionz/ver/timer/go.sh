#!/bin/bash

iverilog test.v $MODULES/jtgng_timer.v -o sim && sim -lxt