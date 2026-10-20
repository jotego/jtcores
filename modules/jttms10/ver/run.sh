#!/bin/bash
set -euo pipefail

main() {
    ver_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    timing_simulator=${JTTMS10_TIMING_SIMULATOR:-verilator}
    bash "$ver_dir/build.sh"
    python3 "$ver_dir/run.py" "$@"
    python3 "$ver_dir/array/programs.py" --fill-boundaries --out "$ver_dir/build/fill-boundaries.yaml"
    python3 "$ver_dir/run.py" --vectors "$ver_dir/build/fill-boundaries.yaml"
    python3 "$ver_dir/array/programs.py" --fill-rows --out "$ver_dir/build/fill-rows.yaml"
    python3 "$ver_dir/run.py" --vectors "$ver_dir/build/fill-rows.yaml"
    python3 "$ver_dir/array/binary_programs.py" --out "$ver_dir/build/binary-boundaries.yaml"
    python3 "$ver_dir/run.py" --timed-word --hold-after-write --vectors "$ver_dir/build/binary-boundaries.yaml"
    for unit in alu field regs word arch system pixelbus arrayirq binaryirq-timed copyirq-timed fpga-stimulus lineirq lineirq-timed io bus startup \
                cache cachefield cachefield-timed fabric host pixel; do
        bash "$ver_dir/sim.sh" "$unit"
    done
    python3 -B "$ver_dir/timing/test_checker.py"
    python3 -B "$ver_dir/timing/test_published_targets.py"
    python3 -B "$ver_dir/timing/test_fill_oracle.py"
    python3 -B "$ver_dir/timing/test_fill_cases.py"
    python3 -B "$ver_dir/timing/test_line_oracle.py"
    python3 -B "$ver_dir/timing/test_line_cases.py"
    python3 -B "$ver_dir/timing/test_blit_oracle.py"
    python3 -B "$ver_dir/timing/test_blit_cases.py"
    for suite in test_check_results test_transport_payload test_transport_stream \
                 test_transport_schema test_programming_receipt; do
        python3 -B "$ver_dir/fpga/$suite.py"
    done
    run_checker binary-irq-mutations "$ver_dir/array/check_timed_interrupt.py"
    run_checker regular-irq-mutations "$ver_dir/array/check_timed_interrupt.py" --kind regular
    run_checker fpga-stimulus-mutations "$ver_dir/fpga/check_stimulus.py"
    run_checker fpga-external-recovery "$ver_dir/fpga/check_external_recovery.py"
    run_checker bus "$ver_dir/bus_timing/check.py"
    run_checker response "$ver_dir/load_pause/check.py"
    run_checker emu "$ver_dir/emu/check.py"
    # Validate actual mutation detection before starting the larger matrices.
    run_checker mutations "$ver_dir/timing/mutations.py"
    run_timing base
    run_timing wait --wait-states 1
    run_timing stress --wait-states 1 --pause-clocks 7
    run_timing div-hit --case divs_even_boundary_26_hit --pause-clocks 7 --pause-after-clocks 32
    run_timing div-off --case divs_even_boundary_26_off --wait-states 1 --pause-clocks 7 --pause-after-clocks 32
    # Every nonzero sub-state pause must realign a newly allocated data read.
    for pause in 1 2 3 4 5 6; do
        run_timing "phase-$pause" --case load_move_f0_w32_o15_s1_off --case _phase_ \
            --wait-states 1 --pause-clocks "$pause"
    done
    run_checker coverage "$ver_dir/timing/coverage.py"
}

run_checker() {
    local profile=$1
    local script=$2
    shift 2
    local report_args=()
    if [ -n "${JTTMS10_TIMING_REPORT:-}" ]; then
        report_args=(--report "$JTTMS10_TIMING_REPORT.$profile.json")
    fi
    python3 "$script" "${report_args[@]}" "$@"
}

run_timing() {
    local profile=$1
    shift
    local report_args=()
    if [ -n "${JTTMS10_TIMING_REPORT:-}" ]; then
        local report=$JTTMS10_TIMING_REPORT
        if [ "$profile" != base ]; then
            report="$report.$profile.json"
        fi
        report_args=(--report "$report")
    fi
    python3 "$ver_dir/timing/run.py" --simulator "$timing_simulator" "${report_args[@]}" "$@"
}

main "$@"
