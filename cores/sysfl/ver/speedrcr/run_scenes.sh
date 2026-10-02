#!/bin/bash
# Run all captured scenes through the video sim; frames + logs land in sim_results/,
# with MAME-on-top / FPGA-below compare stacks in sim_results/diffs/.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"
mkdir -p sim_results/diffs

for d in refscenes/burst_*/; do
    scene=$(basename "$d")
    echo ">> $scene"
    docker run --rm -v "$HOME/develop/jtpublicfork":/jtcores -v "$HOME/develop/jotego-support":/jotego \
        -e JOTEGO=/jotego -w /jtcores/cores/sysfl/ver/speedrcr --entrypoint bash jotego/simulator:arm64 \
        -c "source /jtcores/setprj.sh >/dev/null 2>&1; jtsim -s $scene -video 8 -d NOMAIN" \
        > "sim_results/$scene.log" 2>&1
    last=$(ls frames/frame_*.png 2>/dev/null | tail -1)
    [ -n "$last" ] && cp "$last" "sim_results/$scene.png"
done

python3 - <<'PYEOF'
from PIL import Image
import numpy as np
import glob, os
for f in sorted(glob.glob("sim_results/burst_*.png")):
    scene = os.path.basename(f)[:-4]
    ref = f"refscenes/{scene}/screen.png"
    if not os.path.exists(ref): continue
    a, b = Image.open(ref).convert("RGB"), Image.open(f).convert("RGB")
    na, nb = np.asarray(a, int), np.asarray(b, int)
    d = np.abs(na - nb).sum(axis=2)
    heat = np.zeros((*d.shape, 3), np.uint8)
    heat[...,0] = np.clip(d, 0, 255)              # red = difference
    heat[d == 0] = (0, 48, 0)                     # dark green = identical
    diff = Image.fromarray(heat)
    w = max(a.width, b.width)
    out = Image.new("RGB", (w, a.height*3 + 8), (32,32,32))
    out.paste(a,    (0, 0))
    out.paste(diff, (0, a.height+4))
    out.paste(b,    (0, a.height*2+8))
    out.save(f"sim_results/diffs/{scene}_compare.png")
    pct = 100.0*(d>0).sum()/d.size
    print(f"diffs/{scene}_compare.png  diff={pct:.1f}%")
PYEOF
echo "done"
