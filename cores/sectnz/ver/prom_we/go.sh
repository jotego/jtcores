#!/bin/bash

ROM=$JTGNG/rom/sectionz.rom

iverilog test.v ../../hdl/jtsectionz_prom_we.v \
    -D ROM_LEN=22\'d540704 -D PROM_W=2 -D SIMULATION \
    -D ROM_PATH=\""$ROM"\" \
    -o sim \
    && sim -lxt