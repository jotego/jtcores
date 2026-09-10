#!/bin/bash
# Sim every captured scene of a core through the verilator/docker sim.
#
# Usage:
#   sim_scenes.sh <core> [setname] [scene1 scene2 ...]
#
# Defaults:
#   setname  = core
#   scenes   = every directory under cores/<core>/ver/<core>/scenes/
#
# Output: cores/<core>/ver/<core>/sim_results/<scene>.png  (and .log)
#         (PNG is the default — lossless, for pixel-exact diffs. Override
#          with JTFRAME_FRAMEEXT=jpg if you ever want lossy frames.)
#
# Companion tools:
#   build_diffs.py    -- build MAME/diff/FPGA stacked compare PNGs
#   zoom_slice.py     -- zoom a slice of one scene with a pixel grid
#
# Requires sim-core.sh (Docker jtsim) at the JTROOT.
set -uo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <core> [setname] [scene...]" >&2
    exit 1
fi

CORE="$1"; shift
SETNAME=""
if [ $# -gt 0 ] && [ -d "$(pwd)/cores/$CORE/ver/$1" ] 2>/dev/null; then
    SETNAME="$1"; shift
fi
[ -z "$SETNAME" ] && SETNAME="$CORE"

# SETNAME names the ver/ subdir (where scenes/ + sim_results/ live).  Some
# cores host their scenes under a family name that is NOT a MAME romset
# (e.g. taitob's scenes live in ver/rastan2/ but the romset is "nastar").
# MAMESET overrides the romset passed to sim-core.sh; defaults to SETNAME.
MAMESET="${MAMESET:-$SETNAME}"

# SIMARGS is forwarded verbatim to sim-core.sh -> jtsim. Use it to pass extra
# defines a scene replay needs, e.g. the multi-game header id for darkseal:
#   SIMARGS="-d JTFRAME_SIM_GAMEID=2" tools/scenesim/sim_scenes.sh cninja darkseal
SIMARGS="${SIMARGS:-}"

# Scene replays produce lossless PNG frames (test.cpp emits PNG whenever the
# SIMSCENE macro is defined, which jtsim adds for every -scene run), so the
# saved FPGA result is .png and build_diffs.py / zoom_slice.py diff it
# pixel-for-pixel against the MAME screen.png.

# Locate JTROOT relative to this script (assumes tools/scenesim/sim_scenes.sh).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTROOT="$(cd "$HERE/../.." && pwd)"

SCENES_DIR="$JTROOT/cores/$CORE/ver/$SETNAME/scenes"
OUT_DIR="$JTROOT/cores/$CORE/ver/$SETNAME/sim_results"
mkdir -p "$OUT_DIR"

if [ ! -d "$SCENES_DIR" ]; then
    echo "Missing scenes directory: $SCENES_DIR" >&2
    exit 1
fi
if [ ! -x "$JTROOT/sim-core.sh" ]; then
    echo "Missing $JTROOT/sim-core.sh — this driver delegates to it." >&2
    exit 1
fi

# Choose scenes: explicit args or all sub-directories in scenes/.
scenes=()
if [ $# -gt 0 ]; then
    scenes=("$@")
else
    for d in "$SCENES_DIR"/*/; do
        [ -d "$d" ] || continue
        scenes+=("$(basename "$d")")
    done
fi

if [ ${#scenes[@]} -eq 0 ]; then
    echo "No scenes found under $SCENES_DIR" >&2
    exit 1
fi

echo ">>> core=$CORE setname=$SETNAME"
echo ">>> ${#scenes[@]} scene(s) to sim. Outputs -> $OUT_DIR"
echo

cd "$JTROOT"

ok=0; fail=0
for scene in "${scenes[@]}"; do
    scene_path="$SCENES_DIR/$scene"
    if [ ! -d "$scene_path" ]; then
        echo "----- $scene: directory not found, skipping -----"
        fail=$((fail+1)); continue
    fi
    echo "----- $scene -----"
    rm -rf "cores/$CORE/ver/game/frames"
    rel_scene="../$SETNAME/scenes/$scene"
    if FRAMES=1 ./sim-core.sh "$CORE" "$MAMESET" -s "$rel_scene" $SIMARGS \
            >"$OUT_DIR/$scene.log" 2>&1; then
        last_frame=$(ls -1 "cores/$CORE/ver/game/frames/frame_"*.png 2>/dev/null | tail -n 1)
        if [ -n "$last_frame" ]; then
            cp "$last_frame" "$OUT_DIR/$scene.png"
            echo "  saved $OUT_DIR/$scene.png"
            ok=$((ok+1))
        else
            echo "  sim ran but no frame produced (see $OUT_DIR/$scene.log)" >&2
            fail=$((fail+1))
        fi
    else
        echo "  sim FAILED (see $OUT_DIR/$scene.log)" >&2
        fail=$((fail+1))
    fi
done

echo
echo ">>> $ok succeeded, $fail failed."
echo ">>> Next: build_diffs.py $CORE [$SETNAME]"
