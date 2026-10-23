#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 23-10-2026

set -euo pipefail
seicro_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
if [ "${1:-}" != --inside ]; then
    case "${1:-}" in
        -h|--help)
            printf 'Usage: %s [decode|compare|bus|compat|board|nsc|mr|all]\n' "$0"
            exit 0
            ;;
    esac
    seicro_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
    docker image inspect "$seicro_image" >/dev/null
    exec docker run --rm --pull=never \
        -v "$seicro_repo:/jtcores" \
        -w /jtcores \
        "$seicro_image" -lc \
        'exec bash /jtcores/cores/seicro/ver/game/mcutest.sh --inside "$@"' \
        seicro-mcutest "$@"
fi
shift
seicro_suite=${1:-all}
case "$seicro_suite" in
    decode|compare|bus|compat|board|nsc|mr|all) ;;
    *) printf 'Unsupported MCU suite: %s\n' "$seicro_suite" >&2; exit 2 ;;
esac
export JTROOT="$seicro_repo"
export JTFRAME="$JTROOT/modules/jtframe"
export CORES="$JTROOT/cores"
export MODULES="$JTROOT/modules"
export JTBIN="$JTROOT/release"
unset VERILATOR_ROOT
seicro_scratch="$CORES/seicro/ver/game/scratch/mcu"
mkdir -p "$seicro_scratch"
cd "$JTFRAME/src/jtframe"
go build -o "$seicro_scratch/jtframe" .
cd "$seicro_scratch"
./jtframe mem seicro -t mister --local --inc > generation.log 2>&1
./jtframe files plain seicro -t mister -m SIMULATION,VERILATOR --local >> generation.log 2>&1
./jtframe cfgstr seicro -t mister -o verilator > definitions.txt
: > rtl.f
while IFS= read -r seicro_source; do
    case "$seicro_source" in
        *.v|*.sv)
            case "$seicro_source" in
                /*) printf '%s\n' "$seicro_source" ;;
                *) printf '%s/%s\n' "$JTROOT" "$seicro_source" ;;
            esac >> rtl.f
            ;;
    esac
done < files
awk '!seen[$0]++' rtl.f > rtl.unique.f
mv rtl.unique.f rtl.f

seicro_run() {
    local seicro_label=$1 seicro_top=$2
    shift 2
    local seicro_sources=("$CORES/seicro/ver/hdl/$seicro_top.v")
    if [ "$seicro_top" = m6802_compare_tb ]; then
        seicro_sources+=("$CORES/seicro/ver/hdl/m6802_reference.v" "$MODULES/jt680x/ver/6802/m6802_reference_bus.v")
    fi
    printf 'MCU %s: build\n' "$seicro_label"
    verilator --binary --timing --top-module "$seicro_top" \
        --Mdir "$seicro_scratch/$seicro_label" -j 4 \
        -Wno-fatal -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
        -DSIMULATION -DVERILATOR -I. -I"$JTFRAME/hdl/inc" \
        -f definitions.txt -f rtl.f "${seicro_sources[@]}" "$@" \
        > "$seicro_label-build.log" 2>&1 || {
            tail -n 60 "$seicro_label-build.log"
            return 1
        }
    "$seicro_scratch/$seicro_label/V$seicro_top" > "$seicro_label.log" 2>&1 || {
        cat "$seicro_label.log"
        return 1
    }
    if ! grep -q '^PASS ' "$seicro_label.log"; then
        cat "$seicro_label.log"
        return 1
    fi
    grep '^PASS ' "$seicro_label.log"
}

case "$seicro_suite" in decode|all)
    seicro_run decode m6802_decode_tb
esac
case "$seicro_suite" in compare|all)
    seicro_run compare-6802 m6802_compare_tb
    seicro_run compare-nsc m6802_compare_tb -GNSC=1
esac
case "$seicro_suite" in bus|all)
    seicro_run bus m6802_bus_tb
    for seicro_host in 0 1; do
        for seicro_phase in 0 1 2 3 4 5 6 7; do
            seicro_run "bus-mr-$seicro_phase-host-$seicro_host" m6802_bus_tb \
                -GWITH_MR=1 -GPHASE="$seicro_phase" -GHOST_STALL="$seicro_host"
        done
    done
esac
case "$seicro_suite" in compat|all)
    seicro_run compat m6802_compat_tb
esac
case "$seicro_suite" in board|all)
    seicro_run board mcu_tb
esac
case "$seicro_suite" in nsc|all)
    seicro_run nsc nsc8105_tb
esac
case "$seicro_suite" in mr|all)
    seicro_run mr-6802 mcu_mr_tb
    seicro_run mr-nsc mcu_mr_tb -GNSC=1
esac
