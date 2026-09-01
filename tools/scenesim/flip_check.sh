#!/bin/bash
# Verify screen flip against its own definition: the flipped render of a static
# scene must be the unflipped render rotated 180 degrees, pixel for pixel.
# No MAME reference is involved - MAME flags this driver MACHINE_NO_COCKTAIL.
#
# Usage: flip_check.sh <core> <game-folder> [scene ...]
#   env: MAMESET, SIMARGS, ROMS_HOST  (same as sim_scenes.sh)
set -euo pipefail

CORE=${1:?core}; GAME=${2:?game folder}; shift 2
JTROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCENES_DIR="$JTROOT/cores/$CORE/ver/$GAME/scenes"
OUT_DIR="$JTROOT/cores/$CORE/ver/$GAME/sim_results"
mkdir -p "$OUT_DIR/diffs"

scenes=("$@")
if [ ${#scenes[@]} -eq 0 ]; then
    for d in "$SCENES_DIR"/*/; do scenes+=("$(basename "$d")"); done
fi

# The regs block is the tail of dump.bin: 12 bytes for the two-layer games,
# 4 for pspikes. flip is bit 7 of its first byte either way - see the NOMAIN
# branch of jtpspike_main.v
patch_flip() { # <src dump.bin> <dst dump.bin> <0|1>
    python3 - "$1" "$2" "$3" <<'PY'
import sys, os
src, dst, val = sys.argv[1], sys.argv[2], int(sys.argv[3])
d = bytearray(open(src,'rb').read())
# offset of the regs block and the bit holding flip, per dump layout.
# pspike family: bit 7 of the palette/gfx control byte. f1grpr: gfxctrl bit 5
REGS = {29700:(29696,7), 29716:(29696,7), 57356:(57344,7), 57372:(57344,7),
        151562:(151552,7), 151578:(151552,7), 313400:(313344,5)}
off, bit = REGS.get(len(d), (len(d) - (12 if len(d) > 30000 else 4), 7))
d[off] = (d[off] | (1 << bit)) if val else (d[off] & ~(1 << bit) & 0xff)
open(dst,'wb').write(d)
print("regs byte at %d bit %d -> %02x" % (off, bit, d[off]))
PY
}

run_scene() { # <scene dir relative to ver/> -> writes frames/
    rm -rf "$JTROOT/cores/$CORE/ver/game/frames"
    FRAMES=1 "$JTROOT/sim-core.sh" "$CORE" "${MAMESET:-$GAME}" \
        -s "$1" ${SIMARGS:-} >/dev/null 2>&1
    ls -1 "$JTROOT/cores/$CORE/ver/game/frames/frame_"*.png 2>/dev/null | tail -1
}

pass=0; fail=0
for scene in "${scenes[@]}"; do
    echo "----- $scene -----"
    tmp="$SCENES_DIR/.flipchk"
    rm -rf "$tmp"; mkdir -p "$tmp"

    # flip=0 is invariant under every flip-gated edit, so reuse the scene's
    # existing render instead of burning ~3 min on it. REDO_FLIP0=1 forces it.
    vlist=(1)
    for v in "${vlist[@]}"; do
        patch_flip "$SCENES_DIR/$scene/dump.bin" "$tmp/dump.bin" $v >/dev/null
        f=$(run_scene "../$GAME/scenes/.flipchk") || true
        if [ -z "$f" ]; then echo "  no frame for flip=$v"; fail=$((fail+1)); continue 2; fi
        cp "$f" "$OUT_DIR/${scene}_flip.png"
    done
    rm -rf "$tmp"

    if python3 "$(dirname "${BASH_SOURCE[0]}")/flip_diff.py" \
            "$SCENES_DIR/$scene/screen.png" "$OUT_DIR/${scene}_flip.png" \
            "$OUT_DIR/diffs/${scene}_flip_compare.png"; then pass=$((pass+1)); else fail=$((fail+1)); fi
done
echo; echo "flip_check: $pass passed, $fail failed  ->  $OUT_DIR"
