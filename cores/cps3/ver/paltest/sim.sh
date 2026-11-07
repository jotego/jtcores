#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep] [--dump id] [--limit count]

Options:
  --keep       Build with FST tracing enabled and keep test.fst
  -h, --help   Show this help

All remaining arguments are forwarded to the simulation binary.
EOF
}

keep=0
args=()
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

if [ -z "${JTROOT:-}" ] || [ -z "${JTFRAME:-}" ]; then
    echo "ERROR: source setprj.sh first"
    exit 1
fi

cd "$SCRIPT_DIR"

ln -sfn ../sfiiin/sdram_bank0.bin sdram_bank0.bin
ln -sfn ../sfiiin/sdram_bank1.bin sdram_bank1.bin
ln -sfn ../sfiiin/sdram_bank2.bin sdram_bank2.bin
ln -sfn ../sfiiin/sdram_bank3.bin sdram_bank3.bin
ln -sfn "$HOME/.mame/debug/sfiiin/pal" dumps

trace_args=()
if [ "$keep" -eq 1 ]; then
    trace_args+=(--trace-fst)
fi

# sdram.cpp conditionally compiles the SDRAM wrapper when local UUT.h is in
# the include path, so force this object to follow harness-side adapter edits.
rm -f obj_dir/sdram.o obj_dir/sdram.d

verilator \
    --cc \
    --exe \
    --build \
    --quiet \
    --top-module test \
    -Wno-WIDTHTRUNC \
    -CFLAGS "-std=c++17 -D_JTFRAME_SDRAM_LARGE -I$JTFRAME/verilator -I$SCRIPT_DIR" \
    -DSIMULATION \
    -DJTFRAME_SDRAM_LARGE \
    "${trace_args[@]}" \
    test.v \
    "$JTROOT/cores/cps3/hdl/jtcps3_paldma.v" \
    "$JTFRAME/hdl/ram/jtframe_dual_ram.v" \
    "$JTFRAME/hdl/ram/jtframe_dual_ram16.v" \
    "$JTFRAME/hdl/sdram/jtframe_cache_mux.v" \
    "$JTFRAME/hdl/sdram/jtframe_cache_mux_arb.v" \
    "$JTFRAME/hdl/sdram/jtframe_cache_mux_flush.v" \
    "$JTFRAME/hdl/sdram/jtframe_cache.sv" \
    "$JTFRAME/hdl/sdram/jtframe_cache_ctrl.sv" \
    "$JTFRAME/hdl/sdram/jtframe_cache_req.sv" \
    "$JTFRAME/hdl/sdram/jtframe_cache_data.sv" \
    "$JTFRAME/hdl/sdram/jtframe_cache_tags.sv" \
    "$JTFRAME/hdl/sdram/jtframe_burst_sdram.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_init.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_mode.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_rfsh.v" \
    "$JTFRAME/hdl/sdram/jtframe_sdram64_bank.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_ctrl.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_mux.v" \
    "$JTFRAME/hdl/sdram/jtframe_burst_io.v" \
    test.cpp \
    "$JTFRAME/verilator/sdram.cpp"

./obj_dir/Vtest "${args[@]}"
