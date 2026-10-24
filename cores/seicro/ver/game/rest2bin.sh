#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 15-10-2026

set -euo pipefail
if [ "${1:-}" = --delete ]; then
    rm -f videoram.bin colorram.bin spriteram0.bin spriteram1.bin row_scroll.bin seicro_portb.hex
    if [ -n "${SEICRO_NVRAM_FILE:-}" ]; then
        [ "$(wc -c < "$SEICRO_NVRAM_FILE" | tr -d ' ')" = 256 ]
        cp "$SEICRO_NVRAM_FILE" nvram.bin
    fi
    if [ -z "${SEICRO_SCENE_DUMP:-}" ]; then exit 0; fi
    seicro_dump=$SEICRO_SCENE_DUMP
else
    seicro_dump=${1:-rest.bin}
fi
[ "$(wc -c < "$seicro_dump" | tr -d ' ')" = 1729 ]
dd if="$seicro_dump" of=videoram.bin bs=1 count=1024
dd if="$seicro_dump" of=colorram.bin bs=1 skip=1024 count=512
dd if="$seicro_dump" of=spriteram0.bin bs=1 skip=1536 count=128
dd if="$seicro_dump" of=spriteram1.bin bs=1 skip=1664 count=32
dd if="$seicro_dump" of=row_scroll.bin bs=1 skip=1696 count=32
od -An -tx1 -j1728 -N1 "$seicro_dump" > seicro_portb.hex
