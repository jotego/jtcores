#!/bin/bash
jtutil sdram
# by frame 1800 the PCM ROM check is done (result visible at frame 2839)
jtsim -inputs rom_test.in -video 2860 -w 320
