#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
RUNS=${RUNS:-"0,0,0,0 1,0,0,0 2,0,0,0 3,0,0,0 0,1,0,0 0,0,31,15 0,0,0,6 0,1,31,0 0,0,-32,-16 3,1,-5,7"}
TMP=$(mktemp -d)
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || exit 1
N=0
for R in $RUNS; do
    IFS=, read D S H V <<< "$R"
    iverilog -g2012 test.v ../../hdl/jtpopeye_ana.v ../../hdl/jtpopeye_dbl.v ../../hdl/jtpopeye_timing.v \
        $JTFRAME/hdl/ram/jtframe_prom.v $JTFRAME/hdl/ram/jtframe_dual_ram.v \
        -DSIMULATION -DPROM=\"$TMP/tpp2-v.7j\" -DDEFL=$D -DNARROW=$S -DHPOS=$H -DVPOS=$V \
        -s test -o $TMP/sim$N || { rm -rf $TMP; exit 1; }
    ( vvp -n $TMP/sim$N > $TMP/log$N 2>&1; echo $? > $TMP/res$N ) &
    N=$((N+1))
done
wait
RESULT=0
for ((i=0; i<N; i++)); do
    cat $TMP/log$i
    [ "$(cat $TMP/res$i)" = 0 ] || RESULT=1
    grep -q "^PASS" $TMP/log$i || RESULT=1
done
rm -rf $TMP
exit $RESULT
