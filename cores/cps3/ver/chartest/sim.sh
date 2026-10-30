#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep] [--dumps path] [--dump id] [--first id] [--last id] [--limit count]

Options:
  --keep             Build with FST tracing enabled and keep test.fst
  --dumps <path>     Directory containing YAML/BIN dump corpus.
  --dump <id>        Select only one dump by id.
  --first <id>       Select dumps with id >= first.
  --last <id>        Select dumps with id <= last.
  --limit <count>    Limit number of dumps to process.
  -h, --help         Show this help.

All remaining arguments are forwarded to the simulation binary.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
keep=0
args=()

while [ $# -gt 0 ]; do
    case "$1" in
        --keep)
            keep=1
            shift
            ;;
        --dumps|--dump|--first|--last|--limit)
            if [ $# -lt 2 ]; then
                echo "ERROR: $1 requires an argument" >&2
                usage
                exit 1
            fi
            args+=("$1" "$2")
            shift 2
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

for bank in 0 1 2 3; do
    src="../sfiiin/sdram_bank${bank}.bin"
    if [ ! -f "$src" ]; then
        echo "ERROR: missing SDRAM bank file '$src'" >&2
        exit 1
    fi
    ln -sfn "$src" "sdram_bank${bank}.bin"
done

if [ ! -d "$HOME/.mame/debug/sfiiin/char" ]; then
    echo "ERROR: missing dump directory '$HOME/.mame/debug/sfiiin/char'" >&2
    exit 1
fi
ln -sfn "$HOME/.mame/debug/sfiiin/char" dumps

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
    "$JTROOT/cores/cps3/hdl/jtcps3_chardma.v" \
    "$JTFRAME/hdl/ram/jtframe_dual_ram.v" \
    "$JTFRAME/hdl/ram/jtframe_dual_ram16.v" \
    "$JTFRAME/hdl/ram/jtframe_dual_ram32.v" \
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
