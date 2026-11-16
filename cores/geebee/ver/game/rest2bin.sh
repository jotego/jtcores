#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 10-11-2026

set -euo pipefail
if [[ "${1:-}" == --delete ]]; then
    rm -f vram.bin scene_mmr.hex
    if [[ -n "${GEEBEE_SCENE_DIR:-}" ]]; then
        scene_dir=$GEEBEE_SCENE_DIR
        [[ $(wc -c < "$scene_dir/dump.bin") -eq 1024 ]] || exit 1
        [[ $(wc -c < "$scene_dir/mmr.bin") -eq 6 ]] || exit 1
        cp "$scene_dir/dump.bin" vram.bin
        od -An -tx1 -v "$scene_dir/mmr.bin" > scene_mmr.hex
    fi
    exit 0
fi
scene_dir=${GEEBEE_SCENE_DIR:?Expected GEEBEE_SCENE_DIR}
[[ $(wc -c < rest.bin) -eq 1024 ]] || { echo 'Expected 1024-byte video RAM dump' >&2; exit 1; }
[[ $(wc -c < "$scene_dir/mmr.bin") -eq 6 ]] || { echo 'Expected 6-byte scene register dump' >&2; exit 1; }
cp rest.bin vram.bin
od -An -tx1 -v "$scene_dir/mmr.bin" > scene_mmr.hex
