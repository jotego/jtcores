#!/bin/bash

go.sh -d NOSOUND -d NOMAIN -d NOSCR -d NOCHAR -video 2 \
    -d OBJDMA_SIMFILE=\"toraobj.bin\" -deep | tee sim.log