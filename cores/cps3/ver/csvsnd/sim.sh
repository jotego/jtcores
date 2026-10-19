#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep] [--csv path] [--wav path] [--timeout milliseconds]

Options:
  --keep       Build with FST tracing enabled and keep test.fst
  -h, --help   Show this help

All other arguments are forwarded to the simulation binary.
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

ln -sfn ../sfiiin/sdram_bank1.bin sdram_bank1.bin
ln -sfn "$HOME/.mame/debug/sfiiin/snd.csv" snd.csv

trace_args=()
if [ "$keep" -eq 1 ]; then
    trace_args+=(--trace-fst)
fi

verilator \
    -cc \
    --exe \
    --build \
    --top-module test \
    -CFLAGS "-std=c++17 -D_JTFRAME_SDRAM_LARGE -I$JTFRAME/verilator" \
    -DSIMULATION \
    -DJTFRAME_MCLK=50000000 \
    -DJTFRAME_SDRAM_LARGE \
    "${trace_args[@]}" \
    test.v \
    "$JTROOT/cores/cps3/hdl/jtcps3_sound.v" \
    "$JTFRAME/hdl/jtframe_bcd_cnt.v" \
    "$JTFRAME/hdl/clocking/jtframe_freqinfo.v" \
    "$JTFRAME/hdl/clocking/jtframe_gated_cen.v" \
    "$JTFRAME/hdl/clocking/jtframe_frac_cen.v" \
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
    "$JTFRAME/verilator/sdram.cpp" \
    "$JTFRAME/verilator/wavewritter.cpp"

./obj_dir/Vtest "${args[@]}"
