#!/bin/bash
ZIP=${1:-/mnt/c/Roms/Mame/popeyeu.zip}
ROMS=${ROMS:-$(dirname $ZIP)}
PARTS=${PARTS:-"0 1 2 3 4 5 6 7 8 9"}
HERE=$(cd $(dirname $0); pwd)
CORE=$HERE/../..
JT=${JTFRAME:-$CORE/../../modules/jtframe}/hdl
WORK=${WORK:-$(mktemp -d)}
mkdir -p $WORK/roms $WORK/run
unzip -q -o "$ZIP" 7a 7b 7c 7e -d $WORK/roms || exit 1
for SET in popeyej popeyebl skyskipr; do
    unzip -q -o "$ROMS/$SET.zip" -d $WORK/roms/$SET || exit 1
done
python3 -I $HERE/gen.py $WORK/roms $WORK/run || exit 1
cd $WORK/run
iverilog -g2005 -DSIMULATION -DJTFRAME_MCLK=48000000 -s test -o sim $HERE/test.v $CORE/hdl/jtpopeye_main.v $CORE/hdl/jtpopeye_cab.v \
    $CORE/hdl/jtpopeye_prot.v \
    $JT/cpu/jtframe_z80.v $JT/cpu/jtframe_z80wait.v $JT/cpu/t80/T80s.v \
    $JT/ram/jtframe_ram.v $JT/clocking/jtframe_gated_cen.v $JT/clocking/jtframe_freqinfo.v $JT/jtframe_bcd_cnt.v || exit 1
for P in $PARTS; do
    vvp -n sim +part=$P $VVP_ARGS > part$P.log &
done
wait
cat $(for P in $PARTS; do echo part$P.log; done) | grep -v "^PASS$\|^FAIL (" | tee sim.log
RES=0
for P in $PARTS; do
    grep -q "^PASS" part$P.log || { echo "FAIL in part $P"; RES=1; }
done
[ $RES = 0 ] && echo PASS | tee -a sim.log
echo "work dir: $WORK"
exit $RES
