#!/usr/bin/env bash

build_sim() {
    local root="$1" objdir="$2"
    verilator --binary --timing --quiet --quiet-build --Wno-fatal \
        -Wno-PINMISSING -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
        -Wno-TIMESCALEMOD -Wno-IMPLICITSTATIC \
        -DJTFRAME_HSIZE_DIV=1 -DJTFRAME_HSIZE_STEP=1 -DJTFRAME_HSIZE_DEPTH=1 \
        --top-module test --Mdir "$objdir" \
        "$root/modules/jtframe/target/mister/hdl/sys/sys_top.v" \
        "$root/modules/jtframe/target/mister/ver/sys_top_platform/stubs.v" \
        "$root/modules/jtframe/target/mister/ver/sys_top_platform/test.v" \
        >/dev/null
}

run_sim() {
    local objdir="$1"
    shift
    "$objdir/Vtest" "$@"
}

cleanup_sim() {
    if [[ -n "${SIM_OBJDIR:-}" && -d "$SIM_OBJDIR" ]]; then
        rm -rf -- "$SIM_OBJDIR"
    fi
}

main() {
    local root
    root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd)
    SIM_OBJDIR=$(mktemp -d "${TMPDIR:-/tmp}/sys_top_platform.XXXXXX")
    trap cleanup_sim EXIT

    command -v verilator >/dev/null || { echo "verilator not found" >&2; return 1; }
    build_sim "$root" "$SIM_OBJDIR"
    run_sim "$SIM_OBJDIR" "$@"
}

main "$@"
