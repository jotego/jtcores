#!/bin/bash

# fram 4096 bytes (4 kB)
dd if=$1 of=fram.bin bs=256 count=16 skip=0
drop1    < fram.bin > fram_hi.bin
drop1 -l < fram.bin > fram_lo.bin

# scra 8192 bytes (8 kB)
dd if=$1 of=scra.bin bs=256 count=32 skip=16
drop1    < scra.bin > scra_hi.bin
drop1 -l < scra.bin > scra_lo.bin

# scrb 8192 bytes (8 kB)
dd if=$1 of=scrb.bin bs=256 count=32 skip=48
drop1    < scrb.bin > scrb_hi.bin
drop1 -l < scrb.bin > scrb_lo.bin

# oram 16384 bytes (16 kB)
dd if=$1 of=oram.bin bs=256 count=64 skip=80
drop1    < oram.bin > oram_hi.bin
drop1 -l < oram.bin > oram_lo.bin

# pal 4096 bytes (4 kB)
dd if=$1 of=pal.bin bs=256 count=16 skip=144


dd if=$1 of=rest.bin bs=256 skip=160
