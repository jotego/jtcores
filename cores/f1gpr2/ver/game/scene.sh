#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
task_root=$(cd "$(dirname "$0")/../../../.." && pwd)
run_dir="$task_root/cores/f1gpr2/ver/f1gp2"
image=${SIM_IMAGE:-jotego/simulator:arm64}
target=${SIM_TARGET:-mister}
layer=all
frames=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --layer) shift; layer=${1:?Missing layer};;
        *[!0-9]*|'') echo "Usage: $0 [--layer all|fg|roz|obj] [frames...]" >&2; exit 1;;
        *) frame=$((10#$1)); ((frame>0)) || exit 1; frames+=("$frame");;
    esac
    shift
done
case "$target" in
    mister|sidi128) ;;
    *) echo "SIM_TARGET must be mister or sidi128" >&2; exit 1;;
esac
case "$layer" in
    all) mask=0f; output=sim_results;;
    fg) mask=01; output=sim_results/fg;;
    roz) mask=02; output=sim_results/roz;;
    obj) mask=08; output=sim_results/obj;;
    *) echo "Unknown layer: $layer" >&2; exit 1;;
esac
if [[ ${#frames[@]} -eq 0 ]]; then
    while IFS= read -r frame; do frames+=("$frame"); done < <(
        find "$run_dir/scenes" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed -n '/^[0-9][0-9]*$/p' | sort -n
    )
fi
[[ ${#frames[@]} -gt 0 ]] || { echo "No scenes; run ver/f1gp2/mamedump.sh first" >&2; exit 1; }
for frame in "${frames[@]}"; do
    scene="$run_dir/scenes/$frame"
    [[ -f "$scene/dump.bin" && $(wc -c < "$scene/dump.bin") -eq 53248 &&
       -f "$scene/mmr.bin" && $(wc -c < "$scene/mmr.bin") -eq 40 ]] || {
        echo "Missing or incomplete scene: $scene" >&2; exit 1;
    }
done
docker image inspect "$image" >/dev/null
mkdir -p "$run_dir/scratch/bin" "$run_dir/scratch/replay" "$run_dir/$output"
docker run --rm --pull=never \
    -e SIM_TARGET="$target" -e SCENE_LAYER="$layer" -e SCENE_MASK="$mask" -e SCENE_OUTPUT="$output" \
    -v "$task_root:/jtroot" -w /jtroot/cores/f1gpr2/ver/f1gp2 \
    "$image" -lc '
        set -euo pipefail
        export JTROOT=/jtroot JTFRAME=/jtroot/modules/jtframe MODULES=/jtroot/modules CORES=/jtroot/cores
        export JTBIN=/jtroot/release ROM=/jtroot/rom RLS=/jtroot/release MRA=/jtroot/release/mra
        export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
        if [ ! -x scratch/bin/jtframe ] ||
           [ -n "$(find "$JTFRAME/src/jtframe" -name "*.go" -newer scratch/bin/jtframe -print -quit)" ]; then
            (cd "$JTFRAME/src/jtframe" && go build -o "$CORES/f1gpr2/ver/f1gp2/scratch/bin/jtframe" .)
        fi
        load=()
        for bank in 0 1 2 3; do
            if [ ! -s "sdram_bank$bank.bin" ]; then load=(-load); fi
        done
        for frame in "$@"; do
            export F1GPR2_SCENE_DUMP="$PWD/scenes/$frame/dump.bin"
            "$CORES/f1gpr2/ver/game/rest2bin.sh" "$F1GPR2_SCENE_DUMP"
            buildlog="scratch/replay/$frame-$SCENE_LAYER.log"
            echo "Replaying f1gp2 scene $frame ($SCENE_LAYER, $SIM_TARGET)"
            if ! jtsim -skipROM "-$SIM_TARGET" -u JTFRAME_180SHIFT -d NOMAIN -q \
                -d SIMSCENE -gfx "$SCENE_MASK" -video 3 "${load[@]}" > "$buildlog" 2>&1; then
                tail -60 "$buildlog" >&2
                exit 1
            fi
            load=()
            picture=$(find frames -maxdepth 1 -name "*.png" | sort | tail -1)
            [ -n "$picture" ] || { echo "No frame produced: $buildlog" >&2; exit 1; }
            cp "$picture" "$SCENE_OUTPUT/$frame.png"
            {
                echo "F1GP2 scene=$frame layer=$SCENE_LAYER target=$SIM_TARGET"
                cksum "$F1GPR2_SCENE_DUMP" "scenes/$frame/mmr.bin"
                sed -n "/DIP sw set/,$ p" "$buildlog"
            } > "$SCENE_OUTPUT/$frame.log"
            echo "Saved $SCENE_OUTPUT/$frame.png"
        done
    ' scene "${frames[@]}"
