#!/usr/bin/env bash
set -euo pipefail

build_sim() {
    local root="$1" objdir="$2"
    shift 2
    verilator --binary --timing --quiet --quiet-build --Wno-fatal \
        -Wno-PINMISSING -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
        -Wno-TIMESCALEMOD -Wno-IMPLICITSTATIC \
        -DJTFRAME_HSIZE_DIV=1 -DJTFRAME_HSIZE_STEP=1 -DJTFRAME_HSIZE_DEPTH=1 \
        "$@" \
        --top-module test --Mdir "$objdir" \
        "$root/modules/jtframe/target/mister/hdl/sys/sys_top.v" \
        "$root/modules/jtframe/target/mister/ver/sys_top_platform/stubs.v" \
        "$root/modules/jtframe/target/mister/ver/sys_top_platform/test.v" \
        >/dev/null
}

run_variant() {
    local root="$1" name="$2"
    shift 2
    local objdir="$SIM_ROOTDIR/$name"
    mkdir -p "$objdir"
    echo "== sys_top platform variant: $name =="
    build_sim "$root" "$objdir" "$@"
    "$objdir/Vtest" "${SIM_ARGS[@]}"
}

cleanup_sim() {
    if [[ -n "${SIM_ROOTDIR:-}" && -d "$SIM_ROOTDIR" ]]; then
        rm -rf -- "$SIM_ROOTDIR"
    fi
}

main() {
    local root
    root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd)
    SIM_ROOTDIR=$(mktemp -d "${TMPDIR:-/tmp}/sys_top_platform.XXXXXX")
    SIM_ARGS=("$@")
    trap cleanup_sim EXIT

    command -v verilator >/dev/null || { echo "verilator not found" >&2; return 1; }
    run_variant "$root" regression-enabled -DJTFRAME_REGRESSION
    run_variant "$root" quick-hdmi-regression -DJTFRAME_REGRESSION -DNOSOUND -DJTFRAME_OSD_NOLOGO -DJTFRAME_NOSTA
    run_variant "$root" explicit-undef
    run_variant "$root" no-hdmi-hard-disable -DJTFRAME_REGRESSION -DMISTER_DEBUG_NOHDMI
    run_variant "$root" crt480i -DJTFRAME_REGRESSION -DJTFRAME_CRT480I
    run_variant "$root" interlaced -DJTFRAME_REGRESSION -DJTFRAME_INTERLACED
}

main "$@"
