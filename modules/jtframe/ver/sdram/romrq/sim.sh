#!/bin/bash

for LATCH  in 0 1; do
for REPACK in 0 1; do

echo LATCH=$LATCH, REPACK=$REPACK
iverilog test.v $JTFRAME/hdl/sdram/jtframe_romrq.v \
    -PLATCH=$LATCH -PREPACK=$REPACK \
    -o sim -Wtimescale \
    -s test && sim -lxt

done
done
