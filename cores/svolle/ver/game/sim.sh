#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

set -euo pipefail
core_dir=$(cd "$(dirname "$0")/../.." && pwd)
repo_dir=$(cd "$core_dir/../.." && pwd)
setname=svolley
if [[ ${1:-} == --set ]]; then
    setname=${2:?Missing set name}
    shift 2
fi
case "$setname" in
    svolley|svolleyk|svolleyu|svolleyua|rabiolep|rpunch) ;;
    *) echo "Unsupported set: $setname" >&2; exit 1;;
esac
run_dir="$core_dir/ver/$setname"
image=${SIMULATOR_IMAGE:-jotego/simulator:arm64}
rom_image="$repo_dir/rom/$setname.rom"
mkdir -p "$run_dir/scratch/bin"
docker image inspect "$image" >/dev/null
if [[ ! -s "$rom_image" || "$core_dir/cfg/mame2mra.toml" -nt "$rom_image" ||
      "$core_dir/cfg/macros.def" -nt "$rom_image" ]]; then
    "$core_dir/ver/game/mra.sh"
fi
if [[ $# == 0 ]]; then set -- -load -video 180; fi
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$repo_dir:/jtcores" \
    -w "/jtcores/cores/svolle/ver/$setname" \
    -e SVOLLE_SET="$setname" \
    -e JTROOT=/jtcores -e JTFRAME=/jtcores/modules/jtframe \
    -e CORES=/jtcores/cores -e MODULES=/jtcores/modules \
    -e JTBIN=/jtcores/release -e ROM=/jtcores/rom \
    -e RLS=/jtcores/release -e MRA=/jtcores/release/mra \
    "$image" -euo pipefail -c '
        helper="$PWD/scratch/bin/jtframe"
        if [[ ! -x "$helper" ]] || [[ -n $(find "$JTFRAME/src/jtframe" -name "*.go" -newer "$helper" -print -quit) ]]; then
            go build -C "$JTFRAME/src/jtframe" -o "$helper" .
        fi
        export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
        exec jtsim -setname "$SVOLLE_SET" -skipROM -mister "$@"
    ' bash "$@"
