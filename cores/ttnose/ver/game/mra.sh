#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 01-11-2026
set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
export JTROOT=$(cd "$core_dir/../.." && pwd)
export JTFRAME="$JTROOT/modules/jtframe" CORES="$JTROOT/cores" JTBIN="$JTROOT/release"
run_dir="$core_dir/ver/tail2nos"
rom_root=${MAME_ROMPATH:-$HOME/.mame/roms-local}
mkdir -p "$run_dir/bin" "$run_dir/build/go-cache" "$run_dir/roms"
helper="$run_dir/bin/jtframemac"
if [[ ! -x "$helper" ]] || [[ -n $(find "$JTFRAME/src/jtframe" -name '*.go' -newer "$helper" -print -quit) ]]; then
    GOCACHE="$run_dir/build/go-cache" go build -C "$JTFRAME/src/jtframe" -o "$helper" .
fi
if [[ -d "$rom_root/tail2nos" ]]; then
    zip -q -j "$run_dir/roms/tail2nos.zip" "$rom_root/tail2nos/"*
elif [[ -f "$rom_root/tail2nos.zip" ]]; then
    cp "$rom_root/tail2nos.zip" "$run_dir/roms/tail2nos.zip"
elif [[ -f "$rom_root/tail2nos.7z" ]]; then
    mkdir -p "$run_dir/roms/tail2nos"
    bsdtar -xf "$rom_root/tail2nos.7z" -C "$run_dir/roms/tail2nos"
    zip -q -j "$run_dir/roms/tail2nos.zip" "$run_dir/roms/tail2nos/"*
else
    echo "Missing tail2nos ROMs in $rom_root" >&2;exit 1
fi
[[ -f "$rom_root/ym2608.zip" ]] || { echo "Missing YM2608 rhythm ROM in $rom_root" >&2; exit 1; }
cp "$rom_root/ym2608.zip" "$run_dir/roms/ym2608.zip"
exec "$helper" mra ttnose --path "$run_dir/roms" --skipPocket "$@"
