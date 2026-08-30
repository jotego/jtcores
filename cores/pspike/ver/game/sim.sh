#!/bin/bash
# Thin wrapper. Scene replay is handled by jtsim itself: -s <dir> loads
# <dir>/dump.bin, runs ../game/dump2bin.sh -> rest2bin.sh to split it into the
# BRAM simfiles, and defines NOMAIN NOSOUND DUMP DUMP_VIDEO SIMSCENE.

jtsim -d JTFRAME_SIM_ROMRQ_NOCHECK "$@"
