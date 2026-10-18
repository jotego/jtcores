#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
OLD=${JT2020:-../../../../../popeye-2020/hdl}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || exit 1
unzip -p "$ZIP" tpp2-v.5n > $TMP/tpp2-v.5n || exit 1
sed -e 's/jtframe_ram #/jt2020_ram #/' -e 's/jtframe_prom #/jt2020_prom #/' "$OLD/jtpopeye_txt.v" > $TMP/jtpopeye_txt_2020.v
iverilog -g2012 test.v ../../hdl/jtpopeye_char.v ../../hdl/jtpopeye_timing.v \
    $TMP/jtpopeye_txt_2020.v "$OLD/jtpopeye_video_dec.v" \
    $JTFRAME/hdl/ram/jtframe_prom.v $JTFRAME/hdl/ram/jtframe_ram.v $JTFRAME/hdl/ram/jtframe_dual_ram.v $JTFRAME/hdl/video/tilemap/jtframe_tilemap.v -DSIMULATION \
    -DPROM=\"$TMP/tpp2-v.7j\" -DCHARROM=\"$TMP/tpp2-v.5n\" \
    -s test -o $TMP/sim || { rm -rf $TMP; exit 1; }
vvp -n $TMP/sim
RESULT=$?
rm -rf $TMP
exit $RESULT
