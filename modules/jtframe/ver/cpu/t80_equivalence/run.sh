#!/usr/bin/env bash

main() {
    set -euo pipefail
    parse_args "$@"
    make_run_dir
    prepare_vectors
    record_provenance
    synthesize_fresh
    replay_native
    replay_verilog checked-in "$checked_in"
    replay_verilog fresh "$run_dir/fresh-T80s.v"
    compare_results
    run_negative_control
}

parse_args() {
    traces=()
    seed=150
    cycles=2000
    while (($#)); do
        case "$1" in
            --trace)
                (($# >= 2)) || { echo "--trace needs a path" >&2; exit 2; }
                traces+=("$2"); shift 2 ;;
            --seed)
                (($# >= 2)) || { echo "--seed needs a value" >&2; exit 2; }
                seed="$2"; shift 2 ;;
            --cycles)
                (($# >= 2)) || { echo "--cycles needs a value" >&2; exit 2; }
                cycles="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: $0 [--trace CSV ...] [--seed N] [--cycles N]"
                echo "Replay each input trace against native VHDL, checked-in Verilog, and fresh GHDL Verilog."
                echo "With no --trace, use deterministic stress inputs (default seed 150, 2000 cycles)."
                exit 0 ;;
            *) echo "unknown option: $1" >&2; exit 2 ;;
        esac
    done
}

make_run_dir() {
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
    artifact_root="$repo_root/tasks/jtcores-150/artifacts/t80-equivalence"
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    run_dir="$artifact_root/run-$stamp-$$"
    mkdir -p "$run_dir"
    checked_in="$repo_root/modules/jtframe/hdl/cpu/t80/T80s.v"
    cpu_dir="$repo_root/modules/jtframe/hdl/cpu/t80"
    sources=(T80_ALU.vhd T80_Reg.vhd T80_MCode.vhd T80.vhd T80s.vhd)
    echo "Replay artifacts: $run_dir"
}

prepare_vectors() {
    args=(prepare --out "$run_dir" --seed "$seed" --cycles "$cycles")
    for trace in "${traces[@]}"; do args+=(--trace "$trace"); done
    python3 "$script_dir/replay.py" "${args[@]}"
}

record_provenance() {
    {
        echo "repo_root=$repo_root"
        echo "branch=$(git -C "$repo_root" branch --show-current)"
        echo "git_head=$(git -C "$repo_root" rev-parse HEAD)"
        echo "ghdl=$(ghdl --version | head -1)"
        echo "iverilog=$(iverilog -V 2>&1 | head -1)"
        echo "python=$(python3 --version 2>&1)"
        echo "generics=Mode=0,T2Write=1,IOWait=1 (VHDL defaults; checked-in generated specialization)"
        echo "fresh_analysis_command=ghdl -a -fsynopsys -fexplicit ${sources[*]}"
        echo "fresh_synthesis_command=ghdl --synth --out=verilog -fsynopsys -fexplicit T80s"
        for source in "${sources[@]}" T80s.v; do
            echo "source_commit[$source]=$(git -C "$repo_root" log -1 --format='%H %cs %s' -- "modules/jtframe/hdl/cpu/t80/$source")"
        done
        echo "--- source hashes ---"
        (cd "$cpu_dir" && sha256sum T80_ALU.vhd T80_Reg.vhd T80_MCode.vhd T80.vhd T80s.vhd T80s.v)
        echo "--- generated file sizes ---"
        wc -lc "$checked_in"
    } > "$run_dir/provenance.txt"
}

synthesize_fresh() {
    mkdir -p "$run_dir/fresh"
    cd "$run_dir/fresh"
    for source in "${sources[@]}"; do
        ghdl -a -fsynopsys -fexplicit "$cpu_dir/$source"
    done > "$run_dir/ghdl-analyze.log" 2>&1
    ghdl --synth --out=verilog -fsynopsys -fexplicit T80s > "$run_dir/fresh-T80s.v" 2> "$run_dir/ghdl-synth.log"
    cp "$run_dir/vectors.bin" "$run_dir/fresh/vectors.bin"
    mkdir -p "$run_dir/native"
    cp "$run_dir/vectors.bin" "$run_dir/native/vectors.bin"
    ghdl -a -fsynopsys -fexplicit "$script_dir/replay_tb.vhd" > "$run_dir/ghdl-tb-analyze.log" 2>&1
    ghdl -e -fsynopsys -fexplicit replay_tb > "$run_dir/ghdl-elaborate.log" 2>&1
    if cmp -s "$run_dir/fresh-T80s.v" "$checked_in"; then text_match=yes; else text_match=no; fi
    echo "fresh_netlist_text_equal_checked_in=$text_match" >> "$run_dir/provenance.txt"
    sha256sum "$run_dir/fresh-T80s.v" >> "$run_dir/provenance.txt"
}

replay_native() {
    mkdir -p "$run_dir/native"
    cd "$run_dir/native"
    cp "$run_dir/vectors.bin" .
    ghdl -r --workdir="$run_dir/fresh" -fsynopsys -fexplicit replay_tb --assert-level=error > "$run_dir/native.log" 2>&1
    mv outputs.csv "$run_dir/native.csv"
}

replay_verilog() {
    local name="$1"
    local rtl="$2"
    mkdir -p "$run_dir/$name"
    cp "$run_dir/vectors.bin" "$run_dir/$name/vectors.bin"
    local rows
    rows="$(< "$run_dir/row_count.txt")"
    (cd "$run_dir/$name" && iverilog -g2012 -s replay_tb -o sim "$rtl" "$script_dir/replay_tb.v" && vvp sim +ROWS="$rows" > "$run_dir/$name.log" 2>&1)
    mv "$run_dir/$name/outputs.csv" "$run_dir/$name.csv"
}

compare_results() {
    python3 "$script_dir/replay.py" compare --run "$run_dir" \
        --native "$run_dir/native.csv" --checked "$run_dir/checked-in.csv" \
        --fresh "$run_dir/fresh.csv" | tee "$run_dir/summary.txt"
}

run_negative_control() {
    local mutant="$run_dir/negative-control/T80s_mutant.v"
    mkdir -p "$run_dir/negative-control"
    sed 's/assign M1_n = u0_n10;/assign M1_n = ~u0_n10;/' "$checked_in" > "$mutant"
    rg -q 'assign M1_n = ~u0_n10;' "$mutant"
    replay_verilog negative-control "$mutant"
    python3 "$script_dir/replay.py" negative --run "$run_dir" \
        --reference "$run_dir/checked-in.csv" --mutant "$run_dir/negative-control.csv" \
        | tee "$run_dir/negative-control-summary.txt"
}

main "$@"
