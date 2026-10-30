#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 29-10-2026
set -euo pipefail
if [ "${1:-}" = --delete ]; then
    rm -f videoram.bin spriteram.bin obj_ctrl_ram.bin palette.bin road_x_ram.bin ground_ram.bin road_prom.bin
    if [ -n "${APACH3_SCENE:-}" ]; then
        "$(dirname "$0")/dump2bin.sh" "$APACH3_SCENE/dump.bin"
        dd if=rom.bin of=sdram_bank0.bin bs=1024 count=1024 conv=swab status=none
        dd if=rom.bin of=sdram_bank1.bin bs=1024 skip=1024 count=2048 conv=swab status=none
        dd if=rom.bin of=sdram_bank2.bin bs=1024 skip=3072 count=128 conv=swab status=none
        dd if=rom.bin of=sdram_bank3.bin bs=1024 skip=3200 count=320 conv=swab status=none
        dd if=/dev/zero of=sdram_bank0.bin bs=1024 count=128 conv=notrunc status=none
        dd if=/dev/zero of=sdram_bank0.bin bs=1024 seek=256 count=128 conv=notrunc status=none
        dd if=/dev/zero of=sdram_bank0.bin bs=1024 seek=640 count=128 conv=notrunc status=none
        dd if=/dev/zero of=sdram_bank3.bin bs=1024 seek=256 count=64 conv=notrunc status=none
        dd if=ground_ram.bin of=sdram_bank2.bin bs=1024 seek=128 conv=swab,notrunc status=none
        dd if=rom.bin of=road_prom.bin bs=1024 skip=3520 count=1 status=none
    fi
    exit
fi
dump=${1:-${APACH3_SCENE:-.}/dump.bin}
[ "$(wc -c < "$dump")" -eq 111616 ] || { echo 'Invalid Apache 3 dump size' >&2; exit 1; }
mmr=$(dirname "$dump")/mmr.bin
[ "$(wc -c < "$mmr")" -eq 36 ] || { echo 'Invalid Apache 3 MMR size' >&2; exit 1; }
dd if="$dump" of=videoram.bin bs=512 skip=32 count=16 status=none
dd if="$dump" of=spriteram.bin bs=512 skip=48 count=32 status=none
dd if="$dump" of=obj_ctrl_ram.bin bs=512 skip=80 count=1 status=none
dd if="$dump" of=palette.bin bs=512 skip=81 count=8 status=none
dd if="$dump" of=road_x_ram.bin bs=512 skip=89 count=1 status=none
dd if="$dump" of=ground_ram.bin bs=512 skip=90 count=128 status=none
cp "$mmr" rest.bin
