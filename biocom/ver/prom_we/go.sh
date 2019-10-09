#!/bin/bash

iverilog test.v ../../hdl/jtbiocom_prom_we.v \
    -D ROM_LEN=22\'hF1100 -D PROM_W=2 -D SIMULATION \
    -o sim \
    && sim -lxt