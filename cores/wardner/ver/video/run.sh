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

if [ ! -x obj_dir/vvid ] || [ tb_video.v -nt obj_dir/vvid ] || [ ../../hdl/jtwardner_video.v -nt obj_dir/vvid ]; then
    verilator --binary --timing -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
        -Wno-BLKSEQ -Wno-MULTIDRIVEN --top-module tb_video -o vvid -j 4 \
        tb_video.v ../../hdl/jtwardner_video.v \
        ../../../../modules/jtframe/hdl/video/jtframe_vtimer.v > verilator.log 2>&1 \
        || { echo "verilator build failed, see verilator.log" >&2; exit 1; }
fi

./obj_dir/vvid +snap="$SNAP" +gfx=. +out="$SNAP/rtl.ppm" "$@" || exit 1
python3 render_ref.py "$SNAP" . "$SNAP/ref.ppm" || exit 1
python3 diff_ppm.py "$SNAP/rtl.ppm" "$SNAP/ref.ppm" "$SNAP/diff.ppm"
