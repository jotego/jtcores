#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
if [[ ${1:-} == --delete ]]; then
    rm -f vram0.bin vram1.bin oram.bin pal.bin bitmap.bin mmr.bin
    exit
fi
dump=${1:-dump.bin}
dd if="$dump" of=vram0.bin bs=1 count=8192 2>/dev/null
dd if="$dump" of=vram1.bin bs=1 skip=8192 count=8192 2>/dev/null
dd if="$dump" of=oram.bin bs=1 skip=16384 count=4096 2>/dev/null
dd if="$dump" of=pal.bin bs=1 skip=20480 count=2048 2>/dev/null
cp "$(dirname "$dump")/mmr.bin" mmr.bin
if [[ $(wc -c < "$dump") -gt 22528 ]]; then
    dd if="$dump" of=bitmap.bin bs=1 skip=22528 count=65536 2>/dev/null
fi
