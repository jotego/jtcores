#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

usage() {
    cat <<'EOF'
Usage: bash ./sim.sh [--keep] [sim arguments]

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

if [ -z "${JTFRAME:-}" ]; then
    echo "ERROR: source setprj.sh first"
    exit 1
fi

AS_BIN="${AS_BIN:-sh-elf-as}"
OBJCOPY_BIN="${OBJCOPY_BIN:-sh-elf-objcopy}"
ASM_SRC="sh7604_mem.s"
ASM_OBJ="sh7604_mem.o"
BIN_OUT="sh7604_mem.bin"

if ! command -v "$AS_BIN" >/dev/null 2>&1; then
    echo "ERROR: ${AS_BIN} not found"
    echo "Set AS_BIN to a GNU SuperH assembler."
    exit 1
fi

if ! command -v "$OBJCOPY_BIN" >/dev/null 2>&1; then
    echo "ERROR: ${OBJCOPY_BIN} not found"
    echo "Set OBJCOPY_BIN to a GNU objcopy that supports SuperH objects."
    exit 1
fi

if [ ! -f "$BIN_OUT" ] || [ "$ASM_SRC" -nt "$BIN_OUT" ] || [ "$ASM_OBJ" -nt "$BIN_OUT" ]; then
    "$AS_BIN" --big --isa=sh2a -o "$ASM_OBJ" "$ASM_SRC"
    "$OBJCOPY_BIN" -O binary -j .text "$ASM_OBJ" "$BIN_OUT"
fi

trace_args=()
if [ "$keep" -eq 1 ]; then
    trace_args+=(--trace-fst)
else
    rm -f test.fst
fi

verilator \
    --cc \
    --exe \
    --build \
    --top-module test \
    -Wno-WIDTHTRUNC \
    -Wno-WIDTHEXPAND \
    -CFLAGS "-std=c++17" \
    -DSIMULATION \
    "${trace_args[@]}" \
    test.v \
    "$JTFRAME/hdl/cpu/jtsh7604.sv" \
    "$JTFRAME/hdl/cpu/sh7604/SH_pkg.sv" \
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
    test.cpp

./obj_dir/Vtest "${args[@]}"
