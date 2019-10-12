#!/bin/bash

iverilog test.v ../../hdl/jttora_prom_we.v \
    -D ROM_LEN=22\'h1F0100 -D PROM_W=1 -D SIMULATION \
    -D ROM_PATH=\"$JTGNG/rom/JTTORA.rom\" \
    -o sim \
    && sim -lxt