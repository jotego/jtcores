#!/bin/bash

SYSNAME=1943
eval `jtcfgstr -target=mist -output=bash -core $SYSNAME`

dd if=rom.bin of=audio_lo.bin skip=320 count=32
dd if=rom.bin of=audio_hi.bin skip=352 count=32

# Generic simulation script from JTFRAME
jtsim -mist -sysname $SYSNAME \
    -d JTFRAME_SIM_ROMRQ_NOCHECK \
    -videow 256 -videoh 224 $*
