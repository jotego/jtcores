#!/bin/bash

g++ pal_bin2hex.cc -o pal_bin2hex || exit 1
pal_bin2hex < biocom_pal.bin
#biocom_obj.bin

go.sh -d NOSOUND -d NOMAIN -d NOSCR -d NOCHAR -d NOMCU -video 2 \
    -d OBJDMA_SIMFILE=\"cage.bin\" -deep | tee sim.log