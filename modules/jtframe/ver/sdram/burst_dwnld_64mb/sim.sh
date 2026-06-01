#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

DEFAULT_JTFRAME="$(cd "$ROOT_DIR/../../.." && pwd)"
if [ -z "${JTFRAME:-}" ] || [ ! -f "$JTFRAME/hdl/sdram/jtframe_burst_sdram.v" ]; then
    JTFRAME="$DEFAULT_JTFRAME"
fi

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep] [sim arguments]

Options:
  --keep             Build with FST tracing enabled and keep test.fst
  --balut-forward    Drive a high/low BALUT header with BALUT_REVERSE=0
  --balut-reverse    Drive a low/high BALUT header with BALUT_REVERSE=1
  -h, --help         Show this help

All remaining arguments are forwarded to the simulation binary. Useful
simulation arguments:

  --bytes N       Transfer only N bytes for a short smoke run
  --keep-data     Keep the generated download.bin
  --progress      Print transfer/readback progress
EOF
}

keep=0
balut_mode=""
args=()
verilator_defs=()

while [ $# -gt 0 ]; do
    case "$1" in
        --keep)
            keep=1
            shift
            ;;
        --balut-forward)
            balut_mode="forward"
            shift
            ;;
        --balut-reverse)
            balut_mode="reverse"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

if [ -n "$balut_mode" ]; then
    verilator_defs+=(-DTEST_BALUT)
    args+=(--header-mode "$balut_mode")
    if [ "$balut_mode" = "reverse" ]; then
        verilator_defs+=(-DTEST_BALUT_REVERSE)
    fi
fi

trace_args=()
if [ "$keep" -eq 1 ]; then
    trace_args+=(--trace-fst)
else
    rm -f test.fst
fi

verilator \
    --quiet \
    --cc \
    --exe \
    --build \
    --top-module test \
    -Wno-WIDTHTRUNC \
    -Wno-WIDTHEXPAND \
    -CFLAGS "-std=c++17 -I$JTFRAME/verilator -D_JTFRAME_SDRAM_LARGE" \
    -DSIMULATION \
    -DJTFRAME_SDRAM_LARGE \
    "${verilator_defs[@]}" \
    "${trace_args[@]}" \
    test.v \
    "$JTFRAME/ver/sdram/burst_sdram_inc/jtframe_burst_sdram.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_sdram.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_mode.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_ctrl.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_mux.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_io.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_init.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_rfsh.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_bank.v" \
    "$JTFRAME/hdl/sdram/jtframe_dwnld.v" \
    driver.cpp \
    "$JTFRAME/verilator/sdram.cpp"

./obj_dir/Vtest "${args[@]}"
