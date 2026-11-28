#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026

set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$here"
if (($# == 0)); then
    for ((frame=300; frame<=6000; frame+=300)); do set -- "$@" "$frame"; done
fi
for frame in "$@"; do
    if [[ ! $frame =~ ^[1-9][0-9]{0,7}$ || ! -s scenes/$frame/screen.png ||
        ! -s scenes/$frame/dump.bin || ! -s scenes/$frame/mmr.bin ]]; then
        printf 'Incomplete numeric scene: %s\n' "$frame" >&2
        exit 1
    fi
done

mkdir -p build sim_results
if ! mkdir build/replay.lock; then
    printf 'A Black Panther replay is already running in %s\n' "$here" >&2
    exit 1
fi
backup=$(mktemp -d "$here/build/replay.XXXXXXXX")
paths=(frames logs rom.bin core.mod framerate test.wav video.bin sdram.old mmr.bin pal.bin scroll.bin obj.bin
    vram1.bin vram2.bin char.bin sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin)
started=false
restore() {
    local rc=$? item
    trap - EXIT
    set +e
    if $started; then
        for item in "${paths[@]}"; do
            rm -rf -- "$item" || rc=1
            if [[ -e $backup/$item || -L $backup/$item ]]; then
                mv -- "$backup/$item" "$item" || rc=1
            fi
        done
    else
        for item in "${paths[@]}"; do
            if [[ -e $backup/$item || -L $backup/$item ]]; then
                mv -- "$backup/$item" "$item" || rc=1
            fi
        done
    fi
    rmdir -- "$backup" build/replay.lock || rc=1
    exit "$rc"
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for item in "${paths[@]}"; do
    if [[ -e $item || -L $item ]]; then mv -- "$item" "$backup/"; fi
done
started=true

replay_scene() {
    local frame=$1 latch
    ../game/rest2bin.sh "scenes/$frame/dump.bin" || return
    jtsim -setname blkpnthr -skipROM -mister -load -d NOMAIN -d NOSOUND -d SIMSCENE \
        -video 4 || return
    latch=$(od -An -tu1 -N1 "scenes/$frame/mmr.bin") || return
    printf 'SCENE_LATCH 0x%02X\n' "$latch"
}

for frame in "$@"; do
    log="sim_results/$frame.log"
    if ! replay_scene "$frame" >"$log" 2>&1; then
        printf 'Replay failed at frame %s. See %s\n' "$frame" "$here/$log" >&2
        exit 1
    fi
    latch=$(od -An -tu1 -N1 "scenes/$frame/mmr.bin")
    if ! grep -Eq 'u_intlatch.*read 4 bytes from offset 0' "$log" ||
        ! grep -Eq "hflip = $(( (latch >> 2) & 1 ))$" "$log" ||
        ! grep -Eq "vflip = $(( (latch >> 3) & 1 ))$" "$log"; then
        printf 'Flip latch restore failed at frame %s. See %s\n' "$frame" "$here/$log" >&2
        exit 1
    fi
    for section in pal:4096 scroll:2048 obj:2048 vram1:8192 vram2:4096 char:65536; do
        name=${section%:*}
        length=${section#*:}
        if ! grep -Eq -- "-$name\\.bin +\\( *$length bytes\\)" "$log"; then
            printf '%s RAM restore failed at frame %s. See %s\n' "$name" "$frame" "$here/$log" >&2
            exit 1
        fi
    done
    grep -Eq '^Frame rate: [0-9]' "$log"
    if grep -Eq 'ERROR:|Blank .* created|memory was not filled' "$log"; then
        printf 'Restore failed at frame %s. See %s\n' "$frame" "$here/$log" >&2
        exit 1
    fi
    pictures=(frames/frame_*.png)
    last=${pictures[@]: -1}
    if [[ ! -s $last ]]; then
        printf 'Replay produced no frame for %s. See %s\n' "$frame" "$here/$log" >&2
        exit 1
    fi
    cp -- "$last" "sim_results/$frame.png"
    printf 'Replayed frame %s\n' "$frame"
done
