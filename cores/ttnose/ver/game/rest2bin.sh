#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 01-11-2026

set -euo pipefail
if [[ ${1:-} == --delete ]]; then
    rm -f rozgfx.bin psac0.bin psac1.bin oram.bin txram.bin pal.bin mmr.bin psac_mmr.bin gga.bin
    if [[ -n ${TTNOSE_SCENE_DUMP:-} ]]; then exec "$0" "$TTNOSE_SCENE_DUMP"; fi
    exit
fi
dump=${TTNOSE_SCENE_DUMP:-${1:-rest.bin}}
registers="$(dirname "$dump")/mmr.bin"
[[ -f "$dump" && $(wc -c < "$dump") -eq 145408 ]] || { echo "Expected a 145408-byte Tail to Nose video dump" >&2; exit 1; }
[[ -f "$registers" && $(wc -c < "$registers") -eq 36 ]] || { echo "Expected a 36-byte Tail to Nose MMR dump" >&2; exit 1; }
split() { dd if="$dump" of="$1.bin" bs=1 skip="$2" count="$3" 2>/dev/null; }
split rozgfx      0      131072
split psac0       131072 1024
split psac1       132096 1024
split oram        133120 4096
split txram       137216 4096
split pal         141312 4096
if ! cmp -s "$registers" mmr.bin; then cp "$registers" mmr.bin; fi
dd if=mmr.bin of=psac_mmr.bin bs=1 count=16 2>/dev/null
dd if=mmr.bin of=gga.bin bs=1 skip=20 count=16 2>/dev/null
