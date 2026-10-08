#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"
DEFAULT_JTFRAME="$(cd "$ROOT_DIR/../../.." && pwd)"
DEFAULT_JTROOT="$(cd "$DEFAULT_JTFRAME/../.." && pwd)"

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep]

Options:
  --keep       Build with FST tracing enabled and keep test.fst
  -h, --help   Show this help

All remaining arguments are forwarded to the simulation binary.
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

if [ -z "${JTFRAME:-}" ] || [ ! -f "$JTFRAME/hdl/cpu/jtsh7604.sv" ]; then
    JTFRAME="$DEFAULT_JTFRAME"
fi

if [ -z "${JTROOT:-}" ] || [ ! -d "$JTROOT/cores" ]; then
    JTROOT="$DEFAULT_JTROOT"
fi

AS_BIN="${AS_BIN:-sh-elf-as}"
OBJCOPY_BIN="${OBJCOPY_BIN:-sh-elf-objcopy}"
ASM_SRC="sh7604_bank0.s"
ASM_OBJ="sh7604_bank0.o"
BIN_OUT="sdram_bank0.bin"

if [ ! -f "$ASM_SRC" ]; then
    echo "ERROR: missing ${ASM_SRC}"
    exit 1
fi

if ! command -v "$AS_BIN" >/dev/null 2>&1; then
    echo "ERROR: ${AS_BIN} not found"
    echo "Set AS_BIN or install the SuperH GNU assembler."
    exit 1
fi

if ! command -v "$OBJCOPY_BIN" >/dev/null 2>&1; then
    echo "ERROR: ${OBJCOPY_BIN} not found"
    echo "Set OBJCOPY_BIN or install the SuperH GNU toolchain."
    exit 1
fi

if [ ! -f "$BIN_OUT" ] || [ "$ASM_SRC" -nt "$BIN_OUT" ] || [ "$ASM_OBJ" -nt "$BIN_OUT" ]; then
    "$AS_BIN" --big --isa=sh2a -o "$ASM_OBJ" "$ASM_SRC"
    "$OBJCOPY_BIN" -O binary -j .text "$ASM_OBJ" "$BIN_OUT"
fi

trace_args=()
if [ "$keep" -eq 1 ]; then
    trace_args+=(--trace-fst -DVERILATOR_KEEP_CPU)
fi

verilator \
    --cc \
    --exe \
    --build \
    --top-module test \
    -Wno-WIDTHTRUNC \
    -CFLAGS "-std=c++17 -I$JTFRAME/verilator" \
    -DSIMULATION \
    -DJTFRAME_MCLK=85909090 \
    -DJTFRAME_SDRAM_LARGE \
    "${trace_args[@]}" \
    test.v \
    "$JTFRAME/hdl/cpu/jtsh7604.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_pkg.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_core_trace.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_core.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH7604_pkg.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH7604_mem.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_mem.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_regfile.sv" \
    "$JTFRAME/hdl/cpu/sh7604/UBC.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SCI.sv" \
    "$JTFRAME/hdl/cpu/sh7604/FRT.sv" \
    "$JTFRAME/hdl/cpu/sh7604/DMAC.sv" \
    "$JTFRAME/hdl/cpu/sh7604/WDT.sv" \
    "$JTFRAME/hdl/cpu/sh7604/MSBY.sv" \
    "$JTFRAME/hdl/cpu/sh7604/MULT.sv" \
    "$JTFRAME/hdl/cpu/sh7604/DIVU.sv" \
    "$JTFRAME/hdl/cpu/sh7604/INTC.sv" \
    "$JTFRAME/hdl/cpu/sh7604/BSC.sv" \
    "$JTFRAME/hdl/cpu/sh7604/CACHE.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH7604.sv" \
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
