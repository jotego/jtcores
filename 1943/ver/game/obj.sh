#!/bin/bash

g++ spr_test.cc -o spr_test || exit 1
spr_test > objdma.bin
#biocom_obj.bin

go.sh -d NOSOUND -d NOMAIN -d NOSCR -d NOCHAR -video 2 \
    -d OBJDMA_SIMFILE=\"objdma.bin\" -deep | tee sim.log