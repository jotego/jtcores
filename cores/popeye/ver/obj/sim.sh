#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JT2020=${JT2020:-../../../../../popeye-2020/hdl/jtpopeye_obj.v}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
for f in tpp2-v.7j tpp2-v.1e tpp2-v.1f tpp2-v.1j tpp2-v.1k; do
    unzip -p "$ZIP" $f > $TMP/$f || { rm -rf $TMP; exit 1; }
done
sed -e 's/module jtpopeye_obj(/module jtpopeye_obj_2020(/' "$JT2020" > $TMP/jtpopeye_obj_2020.v
iverilog -g2012 test.v ../../hdl/jtpopeye_obj.v ../../hdl/jtpopeye_timing.v $TMP/jtpopeye_obj_2020.v \
    $JTFRAME/hdl/ram/jtframe_prom.v -DSIMULATION -DPROM=\"$TMP/tpp2-v.7j\" \
    -DROM1E=\"$TMP/tpp2-v.1e\" -DROM1F=\"$TMP/tpp2-v.1f\" -DROM1J=\"$TMP/tpp2-v.1j\" -DROM1K=\"$TMP/tpp2-v.1k\" \
    -s test -o $TMP/sim || { rm -rf $TMP; exit 1; }
vvp -n $TMP/sim | tee $TMP/log
RESULT=0
grep -q "^PASS" $TMP/log || RESULT=1
grep -q "ERROR\|FAIL" $TMP/log && RESULT=1
rm -rf $TMP
exit $RESULT
