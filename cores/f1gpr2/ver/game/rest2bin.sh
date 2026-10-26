#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
if [[ ${1:-} == --delete ]]; then
    rm -f fgvram.bin rozvram.bin sprcg.bin sprvram.bin pal.bin mmr.bin psac.bin
    if [[ -n ${F1GPR2_SCENE_DUMP:-} ]]; then
        exec "$0" "$F1GPR2_SCENE_DUMP"
    fi
    exit
fi
dump=${1:-rest.bin}
[[ -f "$dump" ]] || { echo "Missing scene dump: $dump" >&2; exit 1; }
registers="$(dirname "$dump")/mmr.bin"
[[ $(wc -c < "$dump") -eq 53248 ]] || { echo "Expected a 53248-byte F1GP2 video dump" >&2; exit 1; }
[[ -f "$registers" && $(wc -c < "$registers") -eq 40 ]] || { echo "Expected a 40-byte F1GP2 mmr.bin" >&2; exit 1; }
split() { dd if="$dump" of="$1.bin" bs=1 skip="$2" count="$3" 2>/dev/null; }
split fgvram      0  4096
split rozvram  4096  8192
split sprcg   12288 32768
split sprvram 45056  4096
split pal     49152  4096
if [[ "$registers" != mmr.bin && "$registers" != ./mmr.bin ]]; then
    cp "$registers" mmr.bin
fi
dd if=mmr.bin of=psac.bin bs=1 skip=8 count=32 2>/dev/null
