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
    elif [ "$unit" = fpga-stimulus ]; then
        for mode in {0..17}; do
            "$model_dir/Vtest" +MODE="$mode"
        done
    elif [ "$unit" = arch ]; then
        for mode in 1 2 3 4 5 6 7 8; do
            "$model_dir/Vtest" +mode="$mode"
        done
    elif [ "$unit" = nmi-system ]; then
        for mode in 1 2 3 4 5; do
            "$model_dir/Vtest" +MODE="$mode"
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
            "$model_dir/Vtest" +FILL_PSIZE="$size" +FILL_PPOP=10
            "$model_dir/Vtest" +FILL_PSIZE="$size" +FILL_XY=1 +FILL_PPOP=10
        done
        for size in 4 8 16; do
            for operation in {16..21}; do
                "$model_dir/Vtest" +FILL_PSIZE="$size" +FILL_PPOP="$operation"
                "$model_dir/Vtest" +FILL_PSIZE="$size" +FILL_XY=1 +FILL_PPOP="$operation"
            done
        done
    elif [ "$unit" = binaryirq-timed ] || [ "$unit" = copyirq-timed ]; then
        local formats=(0 1) mode_arg=XY
        if [ "$unit" = copyirq-timed ]; then
            formats=(0 1 2 3)
            mode_arg=COPY_MODE
        fi
        for size in 1 2 4 8 16; do
            for width in 16 32; do
                local row_words=$((width*size/16))
                for xy in "${formats[@]}"; do
                    for waits in 0 1; do
                        local seen=" "
                        for after in 1 "$row_words" "$((2*row_words-1))" "$((2*row_words))"; do
                            [[ $seen == *" $after "* ]] && continue
                            seen+="$after "
                            for pause in 0 31; do
                                "$model_dir/Vtest" +PSIZE="$size" +WIDTH="$width" "+$mode_arg=$xy" \
                                    +WAIT_STATES="$waits" +IRQ_AFTER="$after" +PAUSE_CLOCKS="$pause"
                            done
                        done
                        "$model_dir/Vtest" +PSIZE="$size" +WIDTH="$width" "+$mode_arg=$xy" \
                            +WAIT_STATES="$waits" +IRQ_AFTER=1 +PAUSE_CLOCKS=7
                    done
                done
            done
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
        fpga-stimulus)
            sources=("$ver_dir/fpga/stimulus/test.sv" "$ver_dir/fpga/jttms10_fpga_stimulus.v")
            return
            ;;
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
        nmi-system) bench=nmi/test.sv ;;
        arrayirq) bench=array/interrupt.sv ;;
        binaryirq-timed) bench=array/timed_interrupt.sv ;;
        copyirq-timed) bench=array/timed_copy_interrupt.sv ;;
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
