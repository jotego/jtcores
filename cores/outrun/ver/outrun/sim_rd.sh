#!/bin/bash
# MAME:
# save rdram.bin,80000,1000,1
# the ,1 is for the sub cpu

cat rdram.bin | jtutil drop1 > rdram_lo.bin
cat rdram.bin | jtutil drop1 -l > rdram_hi.bin

sim.sh -d NOMAIN -d NOSUB -nosnd -video 2 -d GRAY -d FORCE_ROAD $*