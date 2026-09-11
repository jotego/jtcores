#!/usr/bin/env bash
# Frame bench for the Wardner video engine.
#
#   ./run.sh <snapshot dir> [+plusargs...]      e.g. ./run.sh ../main/snap4000 +lat=3
#
# Renders one frame of the snapshot with the RTL and with render_ref.py and
# diffs the two. Needs gfx_*.hex from mkgfx.py in this directory.
set -u
cd "$(dirname "$0")"
SNAP=${1:?usage: $0 <snapshot dir> [+plusargs]}; shift
[ -f gfx_obj.hex ] || { echo "run mkgfx.py first" >&2; exit 2; }

# the ten registers as one hex word a line, in the order tb_video expects
awk -F'[=x]' '{print $NF}' "$SNAP/snap_regs.txt" | awk '{printf "%04x\n", strtonum("0x"$1)+0}' > "$SNAP/snap_regs.hex" 2>/dev/null \
 || python3 -c "
import sys
for l in open('$SNAP/snap_regs.txt'):
    v=l.split('=')[1].strip(); print('%04x' % int(v,0))" > "$SNAP/snap_regs.hex"

RTL="../../hdl/jtwardner_video.v ../../hdl/jtwardner_obj.v ../../hdl/jtwardner_colmix.v"
JTF=../../../../modules/jtframe/hdl
RTL="$RTL $JTF/video/tilemap/jtframe_scroll.v $JTF/video/tilemap/jtframe_scroll_offset.v $JTF/video/tilemap/jtframe_tilemap.v"
NEWER=
for f in $RTL tb_video.v; do [ "$f" -nt obj_dir/vvid ] && NEWER=1; done
if [ ! -x obj_dir/vvid ] || [ -n "$NEWER" ]; then
    verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
        -Wno-BLKSEQ -Wno-MULTIDRIVEN --top-module tb_video -o vvid -j 4 \
        tb_video.v $RTL \
        ../../../../modules/jtframe/hdl/video/jtframe_vtimer.v > verilator.log 2>&1 \
        || { echo "verilator build failed, see verilator.log" >&2; exit 1; }
fi

./obj_dir/vvid +snap="$SNAP" +gfx=. +out="$SNAP/rtl.ppm" "$@" || exit 1
python3 render_ref.py "$SNAP" . "$SNAP/ref.ppm" || exit 1
python3 diff_ppm.py "$SNAP/rtl.ppm" "$SNAP/ref.ppm" "$SNAP/diff.ppm"
