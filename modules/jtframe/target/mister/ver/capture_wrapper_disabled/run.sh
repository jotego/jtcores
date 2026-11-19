#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
build_root=$(mktemp -d "${TMPDIR:-/tmp}/capture-wrapper-disabled.XXXXXX")
trap 'rm -rf -- "$build_root"' EXIT
for variant in fullhdmi-undef nohdmi-explicit-define; do
    objdir="$build_root/$variant"
    args=()
    if [[ $variant == nohdmi-explicit-define ]]; then
        args+=( -DJTFRAME_REGRESSION -DMISTER_DEBUG_NOHDMI )
    fi
    verilator --binary --timing --top-module test \
        -Wno-fatal -Wno-PINMISSING -Wno-UNDRIVEN -Wno-UNUSEDSIGNAL -Wno-WIDTH -Wno-TIMESCALEMOD \
        -DJTFRAME_LF_VW=9 -DJTFRAME_LF_HW=9 -DJTFRAME_MR_FASTIO=0 \
        "${args[@]}" --Mdir "$objdir" \
        -f "$here/gather.f" "$here/test.sv"
    (cd "$here" && "$objdir/Vtest")
done
