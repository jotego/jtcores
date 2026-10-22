#!/bin/bash
set -euo pipefail

main() {
    ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    build_dir="$ver_dir/build"
    local unit_only=""
    if (($#)) && [[ $1 == --unit ]]; then
        if (($# < 2)); then
            echo "usage: $0 --unit NAME" >&2
            return 2
        fi
        unit_only=$2
        shift 2
        case "$unit_only" in
            alu|field|regs|word|arch|system|pixelbus|arrayirq|lineirq|io|bus|startup|cache|cachefield|fabric|host|pixel|earlyfetch) ;;
            *) echo "unknown unit bench: $unit_only" >&2; return 2 ;;
        esac
    fi
    if [[ -n $unit_only && $# -ne 0 ]]; then
        echo "--unit cannot be combined with architectural fixture options" >&2
        return 2
    fi
    python3 "$ver_dir/runtime_test.py"
    bash "$ver_dir/build.sh"
    if [[ -z $unit_only ]]; then
        python3 "$ver_dir/run.py" "$@"
    fi

    local hdl="$ver_dir/../hdl"
    run_bench alu alu/test.v "$hdl/jttms10_alu.v"
    run_bench field field/test.sv "$hdl/jttms10_field.v"
    run_bench regs regs/test.sv "$hdl/jttms10_regs.v"
    run_bench word word/test.sv "$hdl"/*.v
    if [[ -z $unit_only || $unit_only == arch ]]; then
        compile_bench arch arch/test.sv "$hdl"/*.v
        for mode in 1 2 3 4 5 6 7 8; do
            run_binary arch "+mode=$mode"
        done
    fi
    run_bench system system/test.sv "$hdl"/*.v
    run_bench pixelbus pixelbus/test.sv "$hdl"/*.v
    run_bench arrayirq array/interrupt.sv "$hdl"/*.v
    run_bench lineirq line/interrupt.sv "$hdl"/*.v
    run_bench io io/test.sv \
        "$hdl/jttms10_io.v" "$hdl/jttms10_video.v" \
        "$hdl/jttms10_refresh.v" "$hdl/jttms10_host.v"
    run_bench bus bus/test.sv "$hdl/jttms10_bus.v"
    run_bench startup startup/test.sv "$hdl/jttms10_bus.v"
    run_bench cache cache/test.sv "$hdl/jttms10_cache.v"
    run_bench cachefield cachefield/test.sv \
        "$hdl/jttms10_field.v" "$hdl/jttms10_cache.v" "$hdl/jttms10_bus.v"
    run_bench fabric fabric/test.sv \
        "$hdl/jttms10_fabric.v" "$hdl/jttms10_field.v" "$hdl/jttms10_bus.v" \
        "$hdl/jttms10_io.v" "$hdl/jttms10_video.v" \
        "$hdl/jttms10_refresh.v" "$hdl/jttms10_host.v"
    run_bench host host/test.sv \
        "$hdl/jttms10_fabric.v" "$hdl/jttms10_bus.v" "$hdl/jttms10_io.v" \
        "$hdl/jttms10_video.v" "$hdl/jttms10_refresh.v" "$hdl/jttms10_host.v"
    run_bench pixel pixel/test.sv "$hdl/jttms10_pixel.v" "$hdl/jttms10_alu.v"
    run_earlyfetch
}

run_bench() {
    local name=$1
    local bench=$2
    shift 2
    if [[ -n ${unit_only:-} && $unit_only != "$name" ]]; then
        return 0
    fi
    compile_bench "$name" "$bench" "$@"
    run_binary "$name"
}

compile_bench() {
    local name=$1
    local bench=$2
    shift 2
    local mdir="$build_dir/obj_$name"
    verilator --quiet --binary --timing --assert --top-module test -Wno-fatal \
        -I"$build_dir" --Mdir "$mdir" -o Vtest "$ver_dir/$bench" "$@"
}

run_binary() {
    local name=$1
    shift
    local mdir="$build_dir/obj_$name"
    (cd "$build_dir" && timeout --foreground "${JTTMS10_UNIT_TIMEOUT:-120s}" \
        "$mdir/Vtest" "$@")
}

run_earlyfetch() {
    if [[ -n ${unit_only:-} && $unit_only != earlyfetch ]]; then
        return 0
    fi
    local mdir="$build_dir/obj_earlyfetch"
    verilator --quiet --binary --timing --assert --top-module test -Wno-fatal \
        -DJTTMS10_REGRESSION -I"$build_dir" --Mdir "$mdir" -o Vtest \
        "$ver_dir/earlyfetch/test.sv" "$ver_dir/../hdl"/*.v
    run_binary earlyfetch "+MODE=NMI"
    run_binary earlyfetch "+MODE=IRQ"
    run_binary earlyfetch "+MODE=HLT"
    run_binary earlyfetch "+MODE=CF"
    run_binary earlyfetch "+MODE=CD"
}

main "$@"
