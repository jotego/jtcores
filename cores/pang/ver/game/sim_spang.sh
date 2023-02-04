#!/bin/bash

# Simulates up to the demo start, where
# the screen border is missing

# ln -sf $ROM/spang.rom rom.bin
# sim_load.sh

sim.sh -verilator -nosnd -video 1230 -w 1221
