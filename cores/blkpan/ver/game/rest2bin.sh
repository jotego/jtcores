#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026

set -euo pipefail

dump=${1:?Usage: rest2bin.sh SCENE/dump.bin}
if [[ $dump == --delete ]]; then exit 0; fi
mmr=$(dirname -- "$dump")/mmr.bin
if [[ ! -f $dump || ! -f $mmr ]] ||
    [[ $(wc -c <"$dump") -ne 86016 || $(wc -c <"$mmr") -ne 4 ]]; then
    printf 'Invalid Black Panther scene dump: %s\n' "$dump" >&2
    exit 1
fi

dd if="$dump" of=pal.bin    bs=2048 skip=0  count=2  status=none
dd if="$dump" of=scroll.bin bs=2048 skip=2  count=1  status=none
dd if="$dump" of=obj.bin    bs=2048 skip=3  count=1  status=none
dd if="$dump" of=vram1.bin  bs=2048 skip=4  count=4  status=none
dd if="$dump" of=vram2.bin  bs=2048 skip=8  count=2  status=none
dd if="$dump" of=char.bin   bs=2048 skip=10 count=32 status=none
cp -- "$mmr" mmr.bin
