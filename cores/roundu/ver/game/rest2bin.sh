#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 20-10-2026

set -euo pipefail
roundu_set=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../roundup5" && pwd -P)
roundu_output=${ROUNDU_RESTORE_DIR:-$roundu_set/scratch/restore}
roundu_parts=(videoram tx_gfxram palette crtc bg_gfxram spriteram obj_ctrl_ram
    road_ctrl_ram road_pixel_ram road_color_ram road_yclip road_vregs registers)
roundu_sizes=(16384 131072 2048 64 131072 16384 512 4096 4096 4096 2 2 22)
if [ "${1:-}" = --delete ]; then
    for roundu_name in "${roundu_parts[@]}" mmr; do rm -f "$roundu_output/$roundu_name.bin"; done
    exit 0
fi
roundu_dump=${1:-rest.bin}
[ "$(wc -c < "$roundu_dump" | tr -d ' ')" = 309850 ] || { echo "Expected a 309850-byte Round Up 5 dump" >&2; exit 1; }
mkdir -p "$roundu_output"
roundu_offset=0
for roundu_i in "${!roundu_parts[@]}"; do
    roundu_size=${roundu_sizes[$roundu_i]}
    if (( roundu_size >= 64 )); then
        dd if="$roundu_dump" of="$roundu_output/${roundu_parts[$roundu_i]}.bin" bs=64 skip=$((roundu_offset/64)) count=$((roundu_size/64)) 2>/dev/null
    else
        dd if="$roundu_dump" of="$roundu_output/${roundu_parts[$roundu_i]}.bin" bs=1 skip="$roundu_offset" count="$roundu_size" 2>/dev/null
    fi
    roundu_offset=$((roundu_offset+roundu_size))
done
{
    cat "$roundu_output/crtc.bin" "$roundu_output/registers.bin"
    dd if=/dev/zero bs=1 count=10 2>/dev/null
    cat "$roundu_output/road_yclip.bin" "$roundu_output/road_vregs.bin" "$roundu_output/obj_ctrl_ram.bin"
} > "$roundu_output/mmr.bin"
[ "$(wc -c < "$roundu_output/mmr.bin" | tr -d ' ')" = 612 ]
printf 'Restored video RAM and MMR files in %s\n' "$roundu_output"
