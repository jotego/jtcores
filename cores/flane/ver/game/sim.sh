#!/bin/bash

touch gfx_cfg.hex
# jtsim_sdram

# Generic simulation script from JTFRAME
# The game takes ~450 frames after loading before

jtsim -d JT51_NODEBUG  -d JTFRAME_SIM_ROMRQ_NOCHECK $*