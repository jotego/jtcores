#!/usr/bin/env bash
set -euo pipefail

task_args=("$@")
set --
test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd "$test_dir/../../../../../.." && pwd)
source "$project_root/setprj.sh"
set -- "${task_args[@]}"

export JTROOT="$project_root"
export JTFRAME="$project_root/modules/jtframe"
export JTBIN="$project_root/bin"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/jtframe-vbuf-reset.XXXXXX")
trap 'rm -rf -- "$tmp_dir"' EXIT

verilator --binary --timing --Wno-fatal -Wno-PROCASSWIRE \
    -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-TIMESCALEMOD \
    --top-module test --Mdir "$tmp_dir/obj" \
    "$JTFRAME/target/mister/hdl/sys/f2sdram_safe_terminator.sv" \
    "$test_dir/test.v" >/dev/null
"$tmp_dir/obj/Vtest"
