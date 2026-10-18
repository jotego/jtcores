#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
SETTINGS=0
TMP=$(mktemp -d)
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || exit 1
for V in $SETTINGS; do
    iverilog -g2012 test.v ../../hdl/jtpopeye_dbl.v ../../hdl/jtpopeye_timing.v \
        $JTFRAME/hdl/ram/jtframe_prom.v $JTFRAME/hdl/ram/jtframe_dual_ram.v \
        -DSIMULATION -DPROM=\"$TMP/tpp2-v.7j\" \
        -s test -o $TMP/sim$V || { rm -rf $TMP; exit 1; }
    ( vvp -n $TMP/sim$V > $TMP/log$V 2>&1; echo $? > $TMP/res$V ) &
done
wait
RESULT=0
for V in $SETTINGS; do
    cat $TMP/log$V
    [ "$(cat $TMP/res$V)" = 0 ] || RESULT=1
    grep -q "^PASS" $TMP/log$V || RESULT=1
done
rm -rf $TMP
exit $RESULT
