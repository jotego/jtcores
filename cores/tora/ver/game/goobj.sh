#!/bin/bash
# checkout mame2sim.sh for full video simulations

sim.sh -d NOSOUND -d NOMAIN -d NOSCR -d NOCHAR -video 2 \
    -d OBJDMA_SIMFILE=\"toraobj.bin\" -d GRAY -deep | tee sim.log
