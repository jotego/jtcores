#!/bin/bash
set -eu

JOBS=""
SIMUNIT_ARGS=()
SIMUNIT_FILES=""
RUNNER_SCRIPT=""
REPORT_FILE=""
ONLY_GATHER_LIST=""
ONLY_GATHER_PATTERNS=()
LIST_ONLY=0
SHARD=""
SHARD_INDEX=1
SHARD_COUNT=1
TIMES_FILE=""
SAVE_TIMES=""
# seconds assumed for a test missing from the times file
DEFAULT_TIME=30
MAX_SHARDS=64
declare -A TEST_TIMES=()

main() {
    find_project
    parse_args "$@"
    validate_environment
    setup_cleanup

    discover_simunit_files
    filter_simunit_files
    order_by_time
    select_shard

    if [ ! -s "$SIMUNIT_FILES" ]; then
        if [ "$SHARD_COUNT" -gt 1 ]; then
            echo "No tests in shard $SHARD" >&2
        elif [ "${#ONLY_GATHER_PATTERNS[@]}" -gt 0 ]; then
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

find_project() {
    local folder
    local setup

    if [ -n "${JTROOT:-}" ]; then
        return
    fi

    folder="$PWD"
    while :; do
        setup="$folder/setprj.sh"
        if [ -f "$setup" ]; then
            set +u
            source "$setup"
            set -u
            if [ -z "${JTROOT:-}" ]; then
                echo "ERROR: $setup did not define JTROOT." >&2
                exit 1
            fi
            return
        fi
        if [ "$folder" = / ]; then
            echo "ERROR: cannot find setprj.sh from $PWD up to /. Source setprj.sh first or run from inside a JTCORES worktree." >&2
            exit 1
        fi
        folder="$(dirname "$folder")"
    done
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
            --shard)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --shard requires an argument such as 1/3."
                    exit 1
                fi
                shift
                SHARD="$1"
                ;;
            --times)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --times requires a file name."
                    exit 1
                fi
                shift
                TIMES_FILE="$1"
                ;;
            --save-times)
                if [ $# -lt 2 ]; then
                    echo "ERROR: --save-times requires a file name."
                    exit 1
                fi
                shift
                SAVE_TIMES="$1"
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
  simunit-all.sh [--jobs N] [--only WORDS] [--shard K/N] [--times FILE]
                 [--save-times FILE] [--list] [simunit options...]

Options:
  --jobs N       Number of parallel jobs (default: detected CPUs)
  --only WORDS   Include only tests whose gather.f contains any substring from a comma-separated list
  --shard K/N    Run only the K-th of N slices of the tests, so N hosts can
                 share them. Slices have similar total durations and are the
                 same on every host for a given checkout and times file
  --times FILE   Test durations used to start the longest tests first and to
                 balance the shards (default: \$JTFRAME/ver/simunit-times.txt).
                 Tests missing from it count as $DEFAULT_TIME s
  --save-times FILE
                 Write the duration of every test run to FILE, in the
                 --times format. With --only or --shard, FILE lists only
                 the tests that ran
  --list         Show filtered simulation list and exit
  --help         Show this help

All extra arguments are passed to simunit.sh. Each test prints PASS or FAIL
and its duration. The log tail of a failed test follows its FAIL line.

Refresh the times file after adding long tests, with GITHUB_ACTIONS=true so
that tests skipped in CI count as short:
  GITHUB_ACTIONS=true simunit-all.sh --jobs 4 --save-times \$JTFRAME/ver/simunit-times.txt
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
    if [ -n "$SHARD" ]; then
        if ! [[ "$SHARD" =~ ^([0-9]{1,3})/([0-9]{1,3})$ ]]; then
            echo "ERROR: --shard must look like K/N, for example 1/3."
            exit 1
        fi
        SHARD_INDEX="$((10#${BASH_REMATCH[1]}))"
        SHARD_COUNT="$((10#${BASH_REMATCH[2]}))"
        if [ "$SHARD_INDEX" -lt 1 ] || [ "$SHARD_INDEX" -gt "$SHARD_COUNT" ] ||
           [ "$SHARD_COUNT" -gt "$MAX_SHARDS" ]; then
            echo "ERROR: --shard K/N needs 1 <= K <= N <= $MAX_SHARDS."
            exit 1
        fi
    fi
    if [ -z "$TIMES_FILE" ]; then
        TIMES_FILE="$JTFRAME/ver/simunit-times.txt"
    elif [ ! -f "$TIMES_FILE" ]; then
        echo "ERROR: cannot read $TIMES_FILE"
        exit 1
    fi
}

# sorted so that every host computes the same --shard slices. Without
# pipes, so that set -e stops on an incomplete list
discover_simunit_files() {
    local found
    found="$(mktemp)"
    SIMUNIT_FILES="$(mktemp)"
    find "$JTROOT" -type f -name '.simunit' -print0 > "$found"
    LC_ALL=C sort -z "$found" > "$SIMUNIT_FILES"
    rm -f "$found"
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
                if grep -qiF -- "$token" "$gather_file"; then
                    printf '%s\0' "$simunit_file" >> "$filtered"
                    break
                fi
            done
        fi
    done < "$SIMUNIT_FILES"

    rm -f "$SIMUNIT_FILES"
    SIMUNIT_FILES="$filtered"
}

# times file lines: <test folder relative to JTROOT> <seconds>
# Seconds are decimal, leading zeros allowed. Other lines are ignored
load_times() {
    local name secs
    if [ ! -f "$TIMES_FILE" ]; then
        return 0
    fi
    while read -r name secs _; do
        secs="${secs%$'\r'}"
        if [[ "$name" != "#"* ]] && [[ "$secs" =~ ^[0-9]{1,9}$ ]]; then
            TEST_TIMES["$name"]="$((10#$secs))"
        fi
    done < "$TIMES_FILE"
}

test_name() {
    local simunit_dir
    simunit_dir="$(dirname "$1")"
    printf '%s' "${simunit_dir#"$JTROOT/"}"
}

test_time() {
    local name
    name="$(test_name "$1")"
    printf '%s' "${TEST_TIMES["$name"]:-$DEFAULT_TIME}"
}

# longest first, so a long test does not start last. Ties keep name order
order_by_time() {
    local ordered keyed
    local simunit_file
    ordered="$(mktemp)"
    keyed="$(mktemp)"

    load_times
    # a temporary file instead of a pipe, so that set -e catches errors here
    while IFS= read -r -d '' simunit_file; do
        printf '%010d\t%s\0' "$(test_time "$simunit_file")" "$simunit_file"
    done < "$SIMUNIT_FILES" > "$keyed"
    LC_ALL=C sort -z -s -t $'\t' -k1,1r "$keyed" | cut -z -f2- > "$ordered"
    if [ "$(count_tests "$ordered")" -ne "$(count_tests "$SIMUNIT_FILES")" ]; then
        echo "ERROR: lost tests while ordering them by time." >&2
        exit 1
    fi

    rm -f "$SIMUNIT_FILES" "$keyed"
    SIMUNIT_FILES="$ordered"
}

count_tests() {
    tr -cd '\0' < "$1" | wc -c
}

# Gives each test, longest first, to the shard with the least total time so
# far and keeps the tests of shard SHARD_INDEX
select_shard() {
    if [ "$SHARD_COUNT" -eq 1 ]; then
        return 0
    fi

    local selected
    local simunit_file
    local k best
    local loads=()
    selected="$(mktemp)"
    for (( k = 0; k < SHARD_COUNT; k++ )); do
        loads[k]=0
    done

    while IFS= read -r -d '' simunit_file; do
        best=0
        for (( k = 1; k < SHARD_COUNT; k++ )); do
            if [ "${loads[k]}" -lt "${loads[best]}" ]; then
                best=$k
            fi
        done
        loads[best]=$(( loads[best] + $(test_time "$simunit_file") ))
        if [ $(( best + 1 )) -eq "$SHARD_INDEX" ]; then
            printf '%s\0' "$simunit_file" >> "$selected"
        fi
    done < "$SIMUNIT_FILES"

    rm -f "$SIMUNIT_FILES"
    SIMUNIT_FILES="$selected"
}

setup_cleanup() {
    trap cleanup_tmp EXIT
}

list_simunits() {
    LC_ALL=C sort -z "$SIMUNIT_FILES" | while IFS= read -r -d '' simunit_file; do
        simunit_dir="$(dirname "$simunit_file")"
        if [ "${simunit_dir#"$JTROOT/"}" != "$simunit_dir" ]; then
            printf '%s\n' "${simunit_dir#$JTROOT/}"
        else
            printf '%s\n' "$simunit_dir"
        fi
    done
}

create_runner() {
    REPORT_FILE="$(mktemp)"
    RUNNER_SCRIPT="$(mktemp)"
    cat > "$RUNNER_SCRIPT" <<'RUNNER_EOF'
#!/bin/bash
set -eu
SIMUNIT_FILE="$1"
shift
SIMUNIT_DIR="$(dirname "$SIMUNIT_FILE")"
if [ "${SIMUNIT_DIR#"$JTROOT/"}" != "$SIMUNIT_DIR" ]; then
    TEST_NAME="${SIMUNIT_DIR#$JTROOT/}"
else
    TEST_NAME="$SIMUNIT_DIR"
fi

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

START=$SECONDS
if "$JTFRAME/bin/simunit.sh" --run "$SIMUNIT_DIR" "$@" > "$LOG_FILE" 2>&1; then
    printf '%s PASS (%d s)\n' "$TEST_NAME" $(( SECONDS - START ))
else
    printf '%s FAIL (%d s)\n' "$TEST_NAME" $(( SECONDS - START ))
    # awk ends the last line even if the log does not
    tail --lines 30 "$LOG_FILE" | awk '{ print "    " $0 }'
    exit 1
fi
RUNNER_EOF
    chmod +x "$RUNNER_SCRIPT"
}

run_all() {
    local status

    # set -e looks at tee only, parallel's status is read from PIPESTATUS
    parallel -0 -j "$JOBS" "$RUNNER_SCRIPT" "{}" "${SIMUNIT_ARGS[@]}" < "$SIMUNIT_FILES" |
        tee "$REPORT_FILE"
    status="${PIPESTATUS[0]}"
    if [ -n "$SAVE_TIMES" ]; then
        save_times
    fi

    if [ "$status" -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi

    return "$status"
}

save_times() {
    {
        echo "# simunit-all.sh test durations in seconds. See simunit-all.sh --help"
        sed -nE 's/^(\S+) (PASS|FAIL) \(([0-9]+) s\)$/\1 \3/p' "$REPORT_FILE" | LC_ALL=C sort
    } > "$SAVE_TIMES"
}

cleanup_tmp() {
    rm -f "${SIMUNIT_FILES:-}" "${RUNNER_SCRIPT:-}" "${REPORT_FILE:-}"
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
