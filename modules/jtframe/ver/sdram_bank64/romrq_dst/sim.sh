#!/bin/bash

make || exit $?
HDL=../../../hdl

iverilog $HDL/sdram/jtframe_{sdram64*,rom_1slot,rom_2slots,romrq,romrq_bcache,ramslot_ctrl}.v test.v \
    $HDL/ver/mt48lc16m16a2.v -s test -o xsim \
    -DSIMULATION -DSDRAM_SHIFT=3 -DJTFRAME_SDRAM_BANKS \
    -DDUMP -Ptest.SIMLEN=3 && xsim -lxt
rm -f xsim