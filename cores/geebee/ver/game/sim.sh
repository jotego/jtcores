#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 07-11-2026
set -euo pipefail

frames="${1:-30}"
[[ "$frames" =~ ^[0-9]+$ ]] || exit 2
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
set_dir="$repo_root/cores/geebee/ver/geebee"

mkdir -p "$set_dir/bin" "$set_dir/build" "$set_dir/frames"

docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$repo_root:$repo_root" -w "$set_dir" \
    jotego/simulator:arm64 -lc '
set -euo pipefail
export JTROOT="$(realpath "$PWD/../../../..")"
export JTFRAME="$JTROOT/modules/jtframe"
export MODULES="$JTROOT/modules"
export CORES="$JTROOT/cores"
export JTBIN="$JTROOT/release"
export ROM="$JTROOT/rom"
export RLS="$JTROOT/release"
export MRA="$JTROOT/release/mra"
export PATH="$PWD/bin:$JTFRAME/bin:$PATH"
(cd "$JTFRAME/src/jtframe" && go build -o "$OLDPWD/bin/jtframe" .)
"$JTFRAME/bin/jtsim" -mister -setname geebee -skipROM -load -video "$1" > build/boot.log 2>&1
' _ "$frames"
