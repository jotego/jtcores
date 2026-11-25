#!/bin/bash
set -euo pipefail

frame=${1:?usage: load_scene.sh <frame>}
if [[ ! "$frame" =~ ^[0-9]{1,9}$ ]]; then
    echo "Invalid frame number: $frame" >&2
    exit 1
fi
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
scene=$(printf '%05d' "$((10#$frame))")
src="$here/burst_$scene"
if [ ! -f "$src/pal.bin" ]; then
    src="/tmp/blkpan_scene_$scene"
fi
if [ ! -f "$src/pal.bin" ]; then
    echo "No RAM dumps for frame $frame" >&2
    exit 1
fi

python3 - "$src" "$here/.." <<'PY'
import sys
from pathlib import Path

src, dst = map(Path, sys.argv[1:])

def pack(size, *lanes):
    data = bytearray(size * len(lanes))
    for index, name in enumerate(lanes):
        path = src / f"{name}.hex"
        lane = bytes.fromhex(path.read_text())
        if len(lane) != size:
            raise ValueError(f"{path}: expected {size} bytes, got {len(lane)}")
        data[index::len(lanes)] = lane
    return data

palette = (src / "pal.bin").read_bytes()
if len(palette) != 4096:
    raise ValueError(f"{src / 'pal.bin'}: expected 4096 bytes, got {len(palette)}")

images = {
    "pal": palette,
    "scroll": pack(2048, "scrollram"),
    "obj": pack(2048, "objram"),
    "vram1": pack(4096, "vram1_lo", "vram1_hi"),
    "vram2": pack(4096, "vram2"),
    "char": pack(16384, "charram1_lo", "charram1_hi", "charram2_lo", "charram2_hi"),
}
for name, data in images.items():
    (dst / f"{name}.bin").write_bytes(data)
PY

printf 'Loaded scene %s into %s. Run jtsim with -d NOMAIN to keep the RAM contents.\n' "$frame" "$(cd "$here/.." && pwd -P)"
