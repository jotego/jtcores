#!/bin/bash

# generate the SDRAM, just in case
jtutil sdram astormj
# allow time for the VDP RAM test result (MAME reaches GOOD near frame 806;
# RTL timing may differ)
jtsim -d NOMCU -q -video 1000 sim_inputs.cab
