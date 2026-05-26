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
  --keep       Build with FST tracing enabled and keep test.fst
  -h, --help   Show this help

All remaining arguments are forwarded to the simulation binary. Useful
simulation arguments:

  --bytes N       Transfer only N bytes for a short smoke run
  --keep-data     Keep the generated download.bin
  --progress      Print transfer/readback progress
EOF
}

keep=0
args=()

while [ $# -gt 0 ]; do
    case "$1" in
        --keep)
            keep=1
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
    test.cpp \
    "$JTFRAME/verilator/sdram.cpp"

./obj_dir/Vtest "${args[@]}"
