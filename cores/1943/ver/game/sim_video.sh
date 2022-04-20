#!/bin/bash
# Define the scroll position in the NOMAIN section
# of jt1943_game.v
# JTFRAME_SIM_GFXEN=14 hides the character layer
sim.sh $* -video 2 -nosnd -d NOMAIN -d JTFRAME_SIM_GFXEN=14 -verilator
