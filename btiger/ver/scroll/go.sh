#!/bin/bash

iverilog test.v ../../hdl/jtbtiger_scroll.v \
    $JTGNG/modules/jtgng_{cen,timer,tilemap,tile4}.v \
    $JTGNG/modules/jtframe/hdl/ram/jtgng_ram.v \
    -DJTCHAR_LOWER_SIMFILE=',.simfile("bg0.bin")' \
    -DJTCHAR_UPPER_SIMFILE=',.simfile("bg1.bin")' \
    -DSIMULATION \
    -o sim && sim -lxt