#!/bin/bash

dd if=/dev/urandom of=sdram_bank0.bin bs=1K count=128 2> /dev/null
dd if=/dev/urandom of=sdram_bank1.bin bs=1K count=128 2> /dev/null
dd if=/dev/urandom of=sdram_bank2.bin bs=1K count=128 2> /dev/null
dd if=/dev/urandom of=sdram_bank3.bin bs=1K count=128 2> /dev/null
HDL=$JTFRAME/hdl

iverilog $HDL/sdram/jtframe_{sdram64*,rom_1slot,rom_2slots,romrq,romrq_bcache,ramslot_ctrl}.v test.v \
    $HDL/ver/mt48lc16m16a2.v -s test -o xsim \
    -DSIMULATION -DSDRAM_SHIFT=3 \
    -DDUMP -Ptest.SIMLEN=3 && xsim -lxt
rm -f xsim