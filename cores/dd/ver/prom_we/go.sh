#!/bin/bash

if which ncverilog; then
    ncverilog test.v ../../hdl/jtdd_prom_we.v \
        +define+ROM_LEN=22\'h124300 +define+PROM_W=1 +define+SIMULATION \
        +define+ROM_PATH=\"../../../rom/JTDD.rom\" +define+NCVERILOG +access+r
else
    iverilog test.v ../../hdl/jtdd_prom_we.v \
        -D ROM_LEN=22\'h124300 -D PROM_W=1 -D SIMULATION \
        -D ROM_PATH=\"../../../rom/JTDD.rom\" \
        -o sim \
        && sim -lxt
fi

cp sdram.hex bueno.hex
cp sdram.hex nolegal.hex
patch nolegal.hex nolegal.patch