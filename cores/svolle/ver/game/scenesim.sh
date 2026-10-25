#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
repo_dir=$(cd "$core_dir/../.." && pwd)
setname=svolley
if [[ ${1:-} == --set ]]; then
    setname=${2:?Missing set name}
    shift 2
fi
case "$setname" in
    svolley|rabiolep) ;;
    *) echo "Unsupported scene set: $setname" >&2; exit 1;;
esac
run_dir="$core_dir/ver/$setname"
scenes=()
if [[ $# == 0 || ${1:-} == all || ${1:-} == --all ]]; then
    while IFS= read -r scene; do scenes+=("$scene"); done < <(
        for directory in "$run_dir"/scenes/*/; do
            scene=${directory%/}
            scene=${scene##*/}
            if [[ "$scene" =~ ^[0-9]+$ ]]; then printf '%s\n' "$scene"; fi
        done | sort -n
    )
else
    scenes=("$@")
fi
[[ ${#scenes[@]} -gt 0 ]] || { echo "No scenes found: $run_dir/scenes" >&2; exit 1; }
for scene in "${scenes[@]}"; do
    [[ "$scene" =~ ^[0-9]+$ ]] || { echo "Invalid scene: $scene" >&2; exit 1; }
    [[ -f "$run_dir/scenes/$scene/dump.bin" && -f "$run_dir/scenes/$scene/mmr.bin" ]] || {
        echo "Missing restore files: $run_dir/scenes/$scene" >&2; exit 1;
    }
done
mkdir -p "$run_dir/scratch/bin" "$run_dir/sim_results"

if [[ ${SVOLLE_SCENE_CONTAINER:-} != 1 ]]; then
    image=${SIMULATOR_IMAGE:-jotego/simulator:arm64}
    docker image inspect "$image" >/dev/null
    rom_image="$repo_dir/rom/$setname.rom"
    if [[ ! -s "$rom_image" || "$core_dir/cfg/mame2mra.toml" -nt "$rom_image" ||
          "$core_dir/cfg/macros.def" -nt "$rom_image" ]]; then
        "$core_dir/ver/game/mra.sh" >"$run_dir/scratch/scene-rom.log" 2>&1
    fi
    exec docker run --rm --pull=never --entrypoint /bin/bash \
        -v "$repo_dir:/jtcores" \
        -w "/jtcores/cores/svolle/ver/$setname" \
        -e SVOLLE_SCENE_CONTAINER=1 \
        -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe \
        -e CORES=/jtcores/cores -e MODULES=/jtcores/modules \
        -e JTBIN=/jtcores/release -e ROM=/jtcores/rom \
        -e RLS=/jtcores/release -e MRA=/jtcores/release/mra \
        "$image" /jtcores/cores/svolle/ver/game/scenesim.sh --set "$setname" "${scenes[@]}"
fi

cd "$run_dir"
helper="$PWD/scratch/bin/jtframe"
if [[ ! -x "$helper" ]] || [[ -n $(find "$JTFRAME/src/jtframe" -name '*.go' -newer "$helper" -print -quit) ]]; then
    go build -C "$JTFRAME/src/jtframe" -o "$helper" . >scratch/scene-helper.log 2>&1
fi
export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
unset VERILATOR_ROOT
first=1
for scene in "${scenes[@]}"; do
    log="sim_results/$scene.log"
    export SVOLLE_SCENE_DUMP="$PWD/scenes/$scene/dump.bin"
    rm -f sdram_bank[0-3].bin
    printf 'REPLAY %s %s\n' "$setname" "$scene"
    if [[ "$first" == 1 ]]; then
        build_log=scratch/scene-build.log
        if jtsim -setname "$setname" -skipROM -mister -load -batch \
            -d NOMAIN -d NOSOUND -d SIMSCENE -video 3 -time 200 >"$build_log" 2>&1; then
            awk '/^make: Leaving directory / {runtime=1; next} runtime {print}' "$build_log" >"$log"
        else
            result=$?
            echo "Replay failed ($result): $PWD/$build_log" >&2
            exit "$result"
        fi
        first=0
    else
        "$core_dir/ver/game/rest2bin.sh" "$SVOLLE_SCENE_DUMP" >"$log" 2>&1
        rm -rf frames
        mkdir frames
        obj_dir/sim -time 200 >>"$log" 2>&1
    fi
    shopt -s nullglob
    frames=(frames/frame_*.png)
    shopt -u nullglob
    [[ ${#frames[@]} -gt 0 ]] || { echo "No frame produced: $PWD/$log" >&2; exit 1; }
    cp "${frames[${#frames[@]}-1]}" "sim_results/$scene.png"
    printf 'REPLAYED %s %s\n' "$setname" "$scene"
done
printf 'REPLAY_COMPLETE %s %s\n' "$setname" "$PWD/sim_results"
