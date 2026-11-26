#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026
set -euo pipefail

bank=sdram_bank1.bin
saved_bank=build/scene-bank1.bin
if [[ ${1:-} == --delete ]]; then
    if [[ -z ${SHDFRC_SCENE:-} ]]; then
        rm -f bg0.bin bg1.bin fg.bin pal.bin mmr.bin
        if [[ -f "$saved_bank" ]]; then mv "$saved_bank" "$bank"; fi
        exit 0
    fi
    set -- "$SHDFRC_SCENE"
fi
scene=${1:?Expected a Shadow Force scene folder}
scene=${scene%/dump.bin}
dump="$scene/dump.bin"
[[ -f "$dump" && $(wc -c < "$dump") -eq 65536 ]] || { echo "Invalid scene RAM: $dump" >&2; exit 1; }
[[ -f "$scene/mmr.bin" && $(wc -c < "$scene/mmr.bin") -eq 16 ]] || { echo "Invalid scene MMR: $scene" >&2; exit 1; }

[[ -f "$bank" ]] || { echo "Missing SDRAM ROM image: $bank" >&2; exit 1; }
mkdir -p build
if [[ ! -f "$saved_bank" ]]; then
    cp -p "$bank" "$saved_bank.tmp"
    mv "$saved_bank.tmp" "$saved_bank"
fi
dd if="$dump" of=bg0.bin bs=2048 count=2 2>/dev/null
dd if="$dump" of=bg1.bin bs=2048 skip=4 count=1 2>/dev/null
dd if="$dump" of=fg.bin bs=8192 skip=2 count=1 2>/dev/null
dd if="$dump" of="$bank" bs=8192 skip=3 seek=256 count=1 conv=swab,notrunc 2>/dev/null
dd if="$dump" of=pal.bin bs=8192 skip=4 count=4 2>/dev/null
cp "$scene/mmr.bin" mmr.bin
