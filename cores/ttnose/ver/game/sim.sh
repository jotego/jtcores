#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 01-11-2026
set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
repo_dir=$(cd "$core_dir/../.." && pwd)
run_dir="$core_dir/ver/tail2nos"
image=${SIMULATOR_IMAGE:-jotego/simulator:arm64}
mkdir -p "$run_dir/bin" "$run_dir/logs" "$run_dir/frames"
docker image inspect "$image" >/dev/null
if [[ ! -s "$repo_dir/rom/tail2nos.rom" || "$core_dir/cfg/mame2mra.toml" -nt "$repo_dir/rom/tail2nos.rom" || "$core_dir/cfg/macros.def" -nt "$repo_dir/rom/tail2nos.rom" ]]; then
    "$core_dir/ver/game/mra.sh"
fi
if [[ $# == 0 ]]; then set -- -load -video 200 ../game/controls.cab;fi
exec docker run --rm --pull=never --label codex.task=ttnose --entrypoint /bin/bash -v "$repo_dir:/jtcores" \
    -w /jtcores/cores/ttnose/ver/tail2nos \
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe -e CORES=/jtcores/cores \
    -e MODULES=/jtcores/modules -e JTBIN=/jtcores/release -e ROM=/jtcores/rom \
    -e RLS=/jtcores/release -e MRA=/jtcores/release/mra -e JOTEGO=/jtcores \
    "$image" -euo pipefail -c '
        helper="$PWD/bin/jtframe"
        if [[ ! -x "$helper" ]] || [[ -n $(find "$JTFRAME/src/jtframe" -name "*.go" -newer "$helper" -print -quit) ]]; then
            go build -C "$JTFRAME/src/jtframe" -o "$helper" .
        fi
        export PATH="$PWD/bin:$JTFRAME/bin:$PATH"
        exec jtsim -setname tail2nos -skipROM -mister -u JTFRAME_180SHIFT "$@"
    ' bash "$@"
