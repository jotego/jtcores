#!/usr/bin/env bash

build_sim() {
    local root="$1" objdir="$2"
    verilator --binary --timing --quiet --quiet-build --top-module test \
        --Mdir "$objdir" -I"$root/modules/jtframe/ver/inc" \
        -Wno-fatal -Wno-IMPLICITSTATIC -Wno-TIMESCALEMOD \
        "$root/modules/jtframe/target/mister/hdl/sys/mcp23009.sv" \
        "$root/modules/jtframe/target/mister/ver/mcp_mode_filter/i2c_stub.vh" \
        "$root/modules/jtframe/target/mister/ver/mcp_mode_filter/test.v" \
        >/dev/null
}

cleanup_sim() {
    if [[ -n "${SIM_OBJDIR:-}" && -d "$SIM_OBJDIR" ]]; then
        rm -rf -- "$SIM_OBJDIR"
    fi
}

run_sim() {
    local objdir="$1"
    shift
    "$objdir/Vtest" "$@"
}

main() {
    local root
    root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../.." && pwd)
    SIM_OBJDIR=$(mktemp -d "${TMPDIR:-/tmp}/mcp_mode_filter.XXXXXX")
    trap cleanup_sim EXIT

    command -v verilator >/dev/null || { echo "verilator not found" >&2; return 1; }
    build_sim "$root" "$SIM_OBJDIR"
    run_sim "$SIM_OBJDIR" "$@"
}

main "$@"
