#!/bin/bash
sim.sh -d NOMAIN -nosnd -d NOSCR1 -d NOOBJ -d GRAY -w -video 2 -verilator $*

# Use this for compiling
# jtcore vigil -d NOMAIN -q -d NOSCR1 -d NOOBJ -d GRAY