#!/bin/bash

if which ncverilog; then
    ncverilog test.v ../../../dd/hdl/jtdd_prom_we.v \
        +define+ROM_LEN=22\'h190200 +define+PROM_W=1 +define+SIMULATION \
        +define+ROM_PATH=\"../../../rom/JTDD2.rom\" +define+NCVERILOG +access+r \
        +define+DD2
else
    iverilog test.v ../../../dd/hdl/jtdd_prom_we.v \
        -D ROM_LEN=22\'h190200 -D PROM_W=1 -D SIMULATION \
        -D ROM_PATH=\"../../../rom/JTDD2.rom\" -D DD2 \
        -o sim \
        && sim -lxt
fi

cp sdram.hex bueno.hex
#cp sdram.hex nolegal.hex
#patch nolegal.hex nolegal.patch