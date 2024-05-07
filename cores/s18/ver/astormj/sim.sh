#!/bin/bash

# generate the SDRAM, just in case
jtutil sdram
# simulate the test sequence up to the VDP memory test
jtsim -d NOMCU -q -video 800 -inputs
