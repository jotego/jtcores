#!/bin/bash
# Define MAX_THROUGHPUT for max throughput test, inputs will force the SDRAM controller to its maximum
# but only reads are tested
# if left undefined, writes, reads and refresh are tested

make || exit $?

#SIM=cvc64
SIM=iverilog

if [ $SIM = iverilog ]; then
    MACRO=-D
    EXTRA=
    EXTRA2=-lxt
else
    MACRO=+define+
    EXTRA="+dump2fst +fst+parallel2=on"
    EXTRA2=
fi

$SIM test.v ../../hdl/sdram/jtframe_sdram_bank_core.v ../../hdl/ver/mt48lc16m16a2.v \
    -o sim ${MACRO}JTFRAME_SDRAM_BANKS ${MACRO}SIMULATION ${MACRO}MAX_THROUGHPUT ${MACRO}PERIOD=7.5 \
&& sim $EXTRA2
