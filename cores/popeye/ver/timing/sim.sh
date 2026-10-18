#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JT2020=${JT2020:-../../../../../popeye-2020/hdl/jtpopeye_timing.v}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
SETTINGS=0
TMP=$(mktemp -d)
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || exit 1
sed -e 's/module jtpopeye_timing(/module jtpopeye_timing_2020(/' \
    -e 's/jtframe_prom #/jt2020_prom #/' "$JT2020" > $TMP/jtpopeye_timing_2020.v
for V in $SETTINGS; do
    iverilog -g2012 test.v ../../hdl/jtpopeye_timing.v $TMP/jtpopeye_timing_2020.v \
        $JTFRAME/hdl/ram/jtframe_prom.v -DSIMULATION -DPROM=\"$TMP/tpp2-v.7j\" \
        -s test -o $TMP/sim$V || { rm -rf $TMP; exit 1; }
    ( vvp -n $TMP/sim$V > $TMP/log$V 2>&1; echo $? > $TMP/res$V ) &
done
wait
RESULT=0
for V in $SETTINGS; do
    cat $TMP/log$V
    [ "$(cat $TMP/res$V)" = 0 ] || RESULT=1
done
rm -rf $TMP
exit $RESULT
