#!/bin/bash
# MAME:
# save rdram.bin,80000,1000,1
# the ,1 is for the sub cpu
# Use special MAME compilation for sprite dumps

EXTRA=

if [ ! -e OUTRUN.RAM ]; then
    EXTRA="$EXTRA -d GRAY"
fi

sim.sh -d NOMAIN -d NOSUB -nosnd -video 3 $EXTRA -verilator $*
