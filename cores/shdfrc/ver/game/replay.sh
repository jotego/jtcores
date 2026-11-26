#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
set_path=cores/shdfrc/ver/shadfrce
cd "$repo_root/$set_path"
if (($# == 0)); then
    for ((frame=300; frame<=9000; frame+=300)); do set -- "$@" "$frame"; done
fi
for frame in "$@"; do
    [[ "$frame" =~ ^[0-9]+$ && -s "scenes/$frame/dump.bin" && -s "scenes/$frame/mmr.bin" ]] || {
        printf 'Missing scene %s\n' "$frame" >&2
        exit 1
    }
done
[[ -s "$repo_root/rom/shadfrce.rom" ]] || { echo 'Generate the shadfrce ROM with ver/game/sim.sh first' >&2; exit 1; }
mkdir -p bin build sim_results

exec docker run --rm --pull=never --entrypoint /bin/bash --name jtshdfrc-shadfrce-replay \
    -v "$repo_root:/jtcores" -w "/jtcores/$set_path" \
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe \
    -e MODULES=/jtcores/modules -e CORES=/jtcores/cores \
    -e JTBIN=/jtcores/release -e ROM=/jtcores/rom \
    -e RLS=/jtcores/release -e MRA=/jtcores/release/mra \
    jotego/simulator:arm64 -euo pipefail -c '
    export PATH="$PWD/bin:$JTFRAME/bin:$PATH"
    helper="$PWD/bin/jtframe"
    go build -C "$JTFRAME/src/jtframe" -o "$helper" .
    ln -srf "$ROM/shadfrce.rom" rom.bin

    saved=$(mktemp -d build/boot-frames.XXXXXX)
    if [[ -d frames ]]; then mv frames "$saved/frames"; fi
    restore_frames() {
        env -u SHDFRC_SCENE ../game/rest2bin.sh --delete
        rm -rf frames
        if [[ -d "$saved/frames" ]]; then mv "$saved/frames" frames; fi
        rmdir "$saved"
    }
    trap restore_frames EXIT
    env -u SHDFRC_SCENE ../game/rest2bin.sh --delete

    seed=0
    for bank in sdram_bank{0,1,2,3}.bin; do
        if [[ ! -s "$bank" || rom.bin -nt "$bank" || "$CORES/shdfrc/cfg/mem.yaml" -nt "$bank" ||
            "$CORES/shdfrc/cfg/macros.def" -nt "$bank" ]]; then
            seed=1
        fi
    done
    if ((seed)); then
        if ! jtsim -mister -u JTFRAME_180SHIFT -skipROM -load -video 1 > build/scene-rom.log 2>&1; then
            echo "ROM download failed. See build/scene-rom.log" >&2
            exit 1
        fi
    fi

    first=1
    for frame in "$@"; do
        log="sim_results/$frame.log"
        export SHDFRC_SCENE="scenes/$frame"
        if ((first)); then
            if [[ ! -x ../game/dump2bin.sh ]]; then ../game/rest2bin.sh "$SHDFRC_SCENE"; fi
            if ! jtsim -mister -u JTFRAME_180SHIFT -skipROM -batch -fast -d SIMSCENE -d NOSOUND -video 4 > "$log" 2>&1; then
                echo "Scene $frame failed. See $log" >&2
                exit 1
            fi
            first=0
        else
            rm -f frames/frame_*.png frames/frames.crc frame.raw
            if ! { ../game/rest2bin.sh "$SHDFRC_SCENE" && obj_dir/sim --video-limit -time 100; } > "$log" 2>&1; then
                echo "Scene $frame failed. See $log" >&2
                exit 1
            fi
        fi
        png=$(find frames -maxdepth 1 -name "frame_*.png" -type f | LC_ALL=C sort | tail -1)
        [[ -n "$png" ]] || { echo "Scene $frame generated no image. See $log" >&2; exit 1; }
        cp "$png" "sim_results/$frame.png"
        printf "Replayed frame %s\n" "$frame"
    done
' _ "$@"
