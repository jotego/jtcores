#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 23-11-2026
set -euo pipefail

frames="${1:-120}"
[[ "$frames" =~ ^[1-9][0-9]*$ ]] || exit 2
setname="${3:-warpwarp}"
case "$setname" in
    warpwarp|warpwarpr|warpwarpr2|bombbee|cutieq) ;;
    *) exit 2 ;;
esac
game_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$game_dir/../../../.." && pwd)"
set_dir="$repo_root/cores/wrpwrp/ver/$setname"
log=build/boot.log
cabinet=()
if [[ ${2:-} == play ]]; then
    case "$setname" in
        bombbee|cutieq) cabinet=("$game_dir/pinball.cab") ;;
        *) cabinet=("$game_dir/play.cab") ;;
    esac
    log=build/play.log
fi

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
frames="$1"
log="$2"
setname="$3"
shift 3
"$JTFRAME/bin/jtsim" -mister -setname "$setname" -skipROM -load -video "$frames" "$@" > "$log" 2>&1
' _ "$frames" "$log" "$setname" ${cabinet[@]+"${cabinet[@]}"}
