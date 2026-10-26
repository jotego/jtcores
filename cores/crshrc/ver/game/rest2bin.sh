#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 26-10-2026

set -euo pipefail
if [[ ${1:-} == --delete ]]; then
    rm -f fgvram.bin rozvram.bin sprcg.bin sprvram.bin pal.bin sprcg_buf.bin sprvram_buf.bin mmr.bin psac.bin
    if [[ -n ${CRSHRC_SCENE_DUMP:-} ]]; then
        exec "$0" "$CRSHRC_SCENE_DUMP"
    fi
    exit
fi
dump=${1:-rest.bin}
[[ -f "$dump" ]] || { echo "Missing scene dump: $dump" >&2; exit 1; }
registers="$(dirname "$dump")/mmr.bin"
[[ $(wc -c < "$dump") -eq 90112 ]] || { echo "Expected a 90112-byte CRSHRACE video dump" >&2; exit 1; }
[[ -f "$registers" && $(wc -c < "$registers") -eq 40 ]] || { echo "Expected a 40-byte CRSHRACE mmr.bin" >&2; exit 1; }
split() { dd if="$dump" of="$1.bin" bs=1 skip="$2" count="$3" 2>/dev/null; }
split fgvram      0  4096
split rozvram  4096  8192
split sprcg   12288 65536
split sprvram 77824  8192
split pal     86016  4096
if [[ "$registers" != mmr.bin && "$registers" != ./mmr.bin ]]; then
    cp "$registers" mmr.bin
fi
dd if=mmr.bin of=psac.bin bs=1 skip=8 count=32 2>/dev/null

for buffer in sprcg sprvram; do
    cp "$(dirname "$dump")/${buffer}_buf.bin" "${buffer}_buf.bin"
done
