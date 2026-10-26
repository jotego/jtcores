#!/bin/bash

#TEST=dinoboot.bin
TEST=dinosave.bin
CMDCNT=$(wc -l $TEST  | cut -f1 -d" ")

iverilog test.v ../../hdl/jt9346.v -o sim -DSIMULATION \
    -Ptest.CMDCNT=$CMDCNT \
    -Ptest.CMDFILE=\"$TEST\" \
    -DJT9346_SIMULATION \
 && sim -lxt
rm -f sim