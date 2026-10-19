#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

main() {
    if [ "$#" = 0 ]; then
        echo "Usage: $0 UNIT [+bench arguments]" >&2
        return 2
    fi
    ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    unit=$1
    shift
    select_sources
    local model_dir="$ver_dir/build/verilator-$unit"
    python3 "$ver_dir/verilator_build.py" --output "$model_dir" \
        --include "$ver_dir/build" "${parameters[@]}" "${sources[@]}"
    cd "$ver_dir/build"
    if [ "$#" != 0 ]; then
        "$model_dir/Vtest" "$@"
    elif [ "$unit" = arch ]; then
        for mode in 1 2 3 4 5 6 7 8; do
            "$model_dir/Vtest" +mode="$mode"
        done
    elif [ "$unit" = lineirq-timed ]; then
        for waits in 0 1; do
            for after in 1 2 3; do
                "$model_dir/Vtest" +WAIT_STATES="$waits" +IRQ_AFTER="$after"
            done
        done
    elif [ "$unit" = arrayirq ]; then
        for size in 1 2 4 8 16; do
            "$model_dir/Vtest" +FILL_PSIZE="$size"
            "$model_dir/Vtest" +FILL_PSIZE="$size" +FILL_XY=1
        done
    else
        "$model_dir/Vtest"
    fi
}

select_sources() {
    parameters=()
    local bench="$unit/test.sv"
    local hdl_names=()
    case "$unit" in
        alu) bench=alu/test.v; hdl_names=(alu) ;;
        field|regs|bus|cache) hdl_names=("$unit") ;;
        startup) hdl_names=(bus) ;;
        pixel) hdl_names=(pixel alu) ;;
        io) hdl_names=(io video refresh host) ;;
        cachefield) hdl_names=(field cache bus) ;;
        cachefield-timed)
            bench=cachefield/test.sv
            hdl_names=(field cache bus bus_timer)
            parameters=(--parameter TIMING=1)
            ;;
        fabric) hdl_names=(fabric field bus io video refresh host) ;;
        host) hdl_names=(fabric bus io video refresh host) ;;
        word|arch|system|pixelbus) ;;
        arrayirq) bench=array/interrupt.sv ;;
        lineirq) bench=line/interrupt.sv ;;
        lineirq-timed) bench=line/timed_interrupt.sv ;;
        *) echo "Unknown unit: $unit" >&2; return 2 ;;
    esac
    sources=("$ver_dir/$bench")
    if [ "${#hdl_names[@]}" = 0 ]; then
        sources+=("$ver_dir"/../hdl/*.v)
    else
        for name in "${hdl_names[@]}"; do
            sources+=("$ver_dir/../hdl/jttms10_$name.v")
        done
    fi
}

main "$@"
