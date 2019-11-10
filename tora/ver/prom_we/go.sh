#!/bin/bash

JAPROM=$JTGNG/rom/tora/"Tora e no Michi (Japan)".rom
USAROM=$JTGNG/rom/tora/JTTORA.rom

iverilog test.v ../../hdl/jttora_prom_we.v $JTGNG/modules/jtgng_obj32.v \
    -D ROM_LEN=22\'h1F0100 -D PROM_W=1 -D SIMULATION \
    -D ROM_PATH=\""$JAPROM"\" \
    -o sim \
    && sim -lxt