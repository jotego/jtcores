#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTROOT="${JTROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
export JTROOT

JOBS=""
SIMUNIT_ARGS=()
SIMUNIT_FILES=""
RUNNER_SCRIPT=""
ONLY_GATHER_LIST=""
ONLY_GATHER_PATTERNS=()
LIST_ONLY=0

main() {
    parse_args "$@"
    validate_environment
    setup_cleanup

    discover_simunit_files
    filter_simunit_files

    if [ ! -s "$SIMUNIT_FILES" ]; then
        if [ "${#ONLY_GATHER_PATTERNS[@]}" -gt 0 ]; then
            echo "No .simunit files matched --only \"$ONLY_GATHER_LIST\" under $JTROOT"
        else
            echo "No .simunit files found under $JTROOT"
        fi
        return 0
    fi

    if [ "$LIST_ONLY" -eq 1 ]; then
        list_simunits
        return 0
    fi

    create_runner
    run_all
}

parse_args() {
    if command -v nproc >/dev/null 2>&1; then
        JOBS="$(nproc)"
    else
        JOBS=4
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --jobs|-j)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --jobs requires a numeric argument."
                    exit 1
                fi
                shift
                JOBS="$1"
                ;;
            --only|-o)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --only requires a filter word."
                    exit 1
                fi
                shift
                parse_only_patterns "$1"
                ;;
            --list|-l)
                LIST_ONLY=1
                ;;
            --)
                shift
                SIMUNIT_ARGS+=("$@")
                break
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                SIMUNIT_ARGS+=("$1")
                ;;
        esac
        shift
    done
}

show_help() {
    cat <<EOF
simunit-all.sh: run all simunit tests in parallel

Usage:
  simunit-all.sh [--jobs N] [--only WORDS] [--list] [simunit options...]

Options:
  --jobs N       Number of parallel jobs (default: detected CPUs)
  --only WORDS   Include only tests whose gather.f contains any substring from a comma-separated list
  --list         Show filtered simulation list and exit
  --help         Show this help

All extra arguments are passed to simunit.sh.
EOF
}

validate_environment() {
    if ! command -v parallel >/dev/null 2>&1; then
        echo "ERROR: GNU parallel is required to run this script."
        exit 1
    fi
    if ! [[ "$JOBS" =~ ^[0-9]+$ ]] || [ "$JOBS" -lt 1 ]; then
        echo "ERROR: --jobs must be a positive integer."
        exit 1
    fi
}

discover_simunit_files() {
    SIMUNIT_FILES="$(mktemp)"
    find "$JTROOT" -type f -name '.simunit' -print0 > "$SIMUNIT_FILES"
}

filter_simunit_files() {
    if [ "${#ONLY_GATHER_PATTERNS[@]}" -eq 0 ]; then
        return 0
    fi

    local filtered
    local simunit_file simunit_dir gather_file
    filtered="$(mktemp)"

    while IFS= read -r -d '' simunit_file; do
        simunit_dir="$(dirname "$simunit_file")"
        gather_file="$simunit_dir/gather.f"
        if [ -f "$gather_file" ]; then
            for token in "${ONLY_GATHER_PATTERNS[@]}"; do
                if grep -qF -- "$token" "$gather_file"; then
                    printf '%s\0' "$simunit_file" >> "$filtered"
                    break
                fi
            done
        fi
    done < "$SIMUNIT_FILES"

    rm -f "$SIMUNIT_FILES"
    SIMUNIT_FILES="$filtered"
}

setup_cleanup() {
    trap cleanup_tmp EXIT
}

list_simunits() {
    while IFS= read -r -d '' simunit_file; do
        simunit_dir="$(dirname "$simunit_file")"
        if [ "${simunit_dir#"$JTROOT/"}" != "$simunit_dir" ]; then
            printf '%s\n' "${simunit_dir#$JTROOT/}"
        else
            printf '%s\n' "$simunit_dir"
        fi
    done < "$SIMUNIT_FILES"
}

create_runner() {
    RUNNER_SCRIPT="$(mktemp)"
    cat > "$RUNNER_SCRIPT" <<'RUNNER_EOF'
#!/bin/bash
set -eu
SIMUNIT_FILE="$1"
shift
"$JTFRAME/bin/simunit.sh" --run "$(dirname "$SIMUNIT_FILE")" "$@"
RUNNER_EOF
    chmod +x "$RUNNER_SCRIPT"
}

run_all() {
    if ! parallel -0 -j "$JOBS" "$RUNNER_SCRIPT" "{}" "${SIMUNIT_ARGS[@]}" < "$SIMUNIT_FILES"; then
        return 1
    fi
}

cleanup_tmp() {
    rm -f "${SIMUNIT_FILES:-}" "${RUNNER_SCRIPT:-}"
}

parse_only_patterns() {
    local raw
    local token
    local trimmed

    raw="$1"
    ONLY_GATHER_LIST="$raw"
    IFS=',' read -r -a ONLY_GATHER_PATTERNS <<< "$raw"

    for idx in "${!ONLY_GATHER_PATTERNS[@]}"; do
        token="${ONLY_GATHER_PATTERNS[$idx]}"
        trimmed="$(printf '%s' "$token" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [ -z "$trimmed" ]; then
            unset "ONLY_GATHER_PATTERNS[$idx]"
        else
            ONLY_GATHER_PATTERNS[$idx]="$trimmed"
        fi
    done
}

main "$@"
