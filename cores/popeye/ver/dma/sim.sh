#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
ROH=${POPEYE2020:-../../../../../popeye-2020/hdl}/jtpopeye_roh_model.v
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || { rm -rf $TMP; exit 1; }
echo '`timescale 1ns/1ps' > $TMP/jt74_parts.v
sed -n '/^module jt74161(/,/^endmodule/p;/^module jt74138(/,/^endmodule/p' $JTFRAME/hdl/jt74.v >> $TMP/jt74_parts.v
iverilog -g2012 -o $TMP/sim -s test -DSIMULATION -DPROM=\"$TMP/tpp2-v.7j\" "$@" test.v jt7474_2020.v \
    $TMP/jt74_parts.v $ROH ../../hdl/jtpopeye_timing.v $JTFRAME/hdl/ram/jtframe_prom.v \
    ../../hdl/jtpopeye_dma.v || { rm -rf $TMP; exit 1; }
vvp -n $TMP/sim
RESULT=$?
rm -rf $TMP
exit $RESULT
