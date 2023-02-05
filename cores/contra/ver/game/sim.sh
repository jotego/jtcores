#!/bin/bash

touch gfx2_cfg.hex gfx1_cfg.hex

jtsim -d JT51_NODEBUG $*
