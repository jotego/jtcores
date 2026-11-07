#!/usr/bin/env bash

main() {
    set -euo pipefail
    parse_args "$@"
    check_environment
    mkdir -p "$output_dir"
    capture_suite t80_timing t80_timing-rising.csv
    capture_suite t80_interrupts t80_interrupts.csv
    echo "Captured traces in $output_dir"
}

parse_args() {
    local repo_root
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
    output_dir="$repo_root/tasks/jtcores-150/artifacts"
    while (($#)); do
        case "$1" in
            --out)
                (($# >= 2)) || { echo "--out needs a directory" >&2; exit 2; }
                output_dir="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: $0 [--out DIRECTORY]"
                echo "Regenerate the timing and interrupt input traces with +TRACE."
                exit 0 ;;
            *) echo "unknown option: $1" >&2; exit 2 ;;
        esac
    done
    output_dir="$(mkdir -p "$output_dir" && cd "$output_dir" && pwd)"
    repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
    jtframe_dir="${JTFRAME:-$repo_root/modules/jtframe}"
    suite_root="$repo_root/modules/jtframe/ver/cpu"
    work_dir="$(mktemp -d "${TMPDIR:-/tmp}/t80-capture.XXXXXX")"
    trap 'rm -rf "$work_dir"' EXIT
}

check_environment() {
    [[ -d "$jtframe_dir" ]] || { echo "JTFRAME is unset and default path is missing" >&2; exit 1; }
    command -v iverilog >/dev/null || { echo "iverilog is required" >&2; exit 1; }
    command -v vvp >/dev/null || { echo "vvp is required" >&2; exit 1; }
}

capture_suite() {
    local suite="$1"
    local trace_name="$2"
    local source_dir="$suite_root/$suite"
    local suite_dir="$work_dir/$suite"
    local sim_path="$work_dir/$suite.sim"
    local gather_path="$work_dir/$suite-gather.f"
    local sim_output
    local source
    local sources=()

    [[ -d "$source_dir" ]] || { echo "missing suite directory: $source_dir" >&2; exit 1; }
    mkdir -p "$suite_dir"
    cp -a "$source_dir/." "$suite_dir/"
    if [[ -e "$suite_dir/init.go" ]]; then
        (cd "$suite_dir" && go run init.go)
    fi
    while IFS= read -r -d '' source; do sources+=("$source"); done \
        < <(find "$suite_dir" -type f \( -name '*.v' -o -name '*.sv' \) -print0)
    (cd "$suite_dir" && envsubst < gather.f > "$gather_path")
    (cd "$suite_dir" && \
        iverilog -g2012 "${sources[@]}" \
            -I"$jtframe_dir/ver/inc" \
            "$jtframe_dir/hdl/video/jtframe_vtimer.v" \
            "$jtframe_dir/hdl/ver/jtframe_test_clocks.v" \
            -f "$gather_path" -s test -o "$sim_path" -D SIMULATION -D JTFRAME_MCLK=48000000)
    if ! sim_output="$(cd "$suite_dir" && vvp "$sim_path" "+TRACE=$output_dir/$trace_name" 2>&1)"; then
        printf '%s\n' "$sim_output"
        echo "$suite simulation failed" >&2
        exit 1
    fi
    printf '%s\n' "$sim_output"
    if grep -q '^FAIL' <<<"$sim_output" || ! grep -q '^PASS' <<<"$sim_output"; then
        echo "$suite did not report PASS" >&2
        exit 1
    fi
}

main "$@"
