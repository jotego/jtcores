#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-11-2026
set -euo pipefail

frames=${1:-2000}
rom_dir=${2:-"$HOME/.mame/roms-local"}
[[ "$frames" =~ ^[1-9][0-9]*$ ]] || exit 2
rom_dir=$(cd "$rom_dir" && pwd)
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
set_path=cores/shdfrc/ver/shadfrce
set_dir="$repo_root/$set_path"
container=jtshdfrc-shadfrce-boot
image=jotego/simulator:arm64

if docker container inspect "$container" >/dev/null 2>&1; then
    printf 'Container %s already exists\n' "$container" >&2
    exit 1
fi
test -r "$rom_dir/shadfrce.zip"
docker image inspect "$image" >/dev/null
mkdir -p "$set_dir/bin"

docker_args=(--rm --pull=never --entrypoint /bin/bash
    -v "$repo_root:/jtcores" -w "/jtcores/$set_path"
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe
    -e MODULES=/jtcores/modules -e CORES=/jtcores/cores
    -e JTBIN=/jtcores/release -e ROM=/jtcores/rom
    -e RLS=/jtcores/release -e MRA=/jtcores/release/mra)

docker run "${docker_args[@]}" -v "$rom_dir:/mame-roms:ro" \
    "$image" -ec '
        set_dir=$PWD
        (cd "$JTFRAME/src/jtframe" && go build -o "$set_dir/bin/jtframe" .)
        bin/jtframe mra shdfrc --setname shadfrce --path /mame-roms --skipPocket
    '

rom="$repo_root/rom/shadfrce.rom"
test "$(wc -c < "$rom" | tr -d '[:space:]')" -eq $((0xeb0000))
cmp <(dd if="$rom" bs=65536 skip=$((0x4b)) count=$((0x20)) 2>/dev/null) \
    <(unzip -p "$rom_dir/shadfrce.zip" 32j4-0.12)

mkdir -p "$set_dir/frames"
docker run "${docker_args[@]}" --detach --name "$container" "$image" -ec '
    export PATH="$PWD/bin:$JTFRAME/bin:$PATH"
    exec jtsim -mister -u JTFRAME_180SHIFT -setname shadfrce -skipROM -load -video "$1" > boot.log 2>&1
' _ "$frames"
printf '%s\n' "$set_dir/frames"
