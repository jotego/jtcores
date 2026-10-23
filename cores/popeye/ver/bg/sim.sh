#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JT2020=${JT2020:-../../../../../popeye-2020/hdl}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
FAIL=0
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || { rm -rf $TMP; exit 1; }
sed -e 's/\.aw(/.AW(/g' -e 's/\.dw(/.DW(/g' "$JT2020/jtpopeye_bck.v" > $TMP/jtpopeye_bck_2020.v
cp "$JT2020/jtpopeye_video_dec.v" $TMP/
git show ${BG_REF:-ee92af17d}:cores/popeye/hdl/jtpopeye_bg.v | sed 's/^module jtpopeye_bg(/module jtpopeye_bg_ref(/' > $TMP/jtpopeye_bg_ref.v || { rm -rf $TMP; exit 1; }
for RUN in ${RUNS:-0:0:0 0:1:0 0:0:1 1:0:0 1:1:0 2:0:0 3:0:0 3:1:0}; do
    BOARD=${RUN%%:*}; RV=${RUN#*:}; IMG=${RV#*:}; RV=${RV%%:*}
    echo "=== board=$BOARD rv=$RV img=$IMG"
    iverilog -g2012 -o $TMP/sim -s test -DSIMULATION -DJTFRAME_MCLK=48000 -DJT2020 -DREF -DBOARD=$BOARD -DIMG=$IMG -DRV=$RV -DPROM=\"$TMP/tpp2-v.7j\" "$@" test.v \
        ../../hdl/jtpopeye_bg.v $TMP/jtpopeye_bg_ref.v ../../hdl/jtpopeye_timing.v ../../hdl/jtpopeye_dma.v \
        $JTFRAME/hdl/ram/jtframe_ram.v $JTFRAME/hdl/ram/jtframe_prom.v \
        $JTFRAME/hdl/clocking/jtframe_gated_cen.v $JTFRAME/hdl/clocking/jtframe_freqinfo.v $JTFRAME/hdl/jtframe_bcd_cnt.v \
        $TMP/jtpopeye_bck_2020.v $TMP/jtpopeye_video_dec.v || { FAIL=1; continue; }
    vvp -n $TMP/sim | tee $TMP/sim.log
    grep -q "^PASS" $TMP/sim.log || FAIL=1
done
rm -rf $TMP
exit $FAIL
