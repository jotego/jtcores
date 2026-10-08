#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -z "${JTROOT:-}" ]]; then
    echo "[ERROR] Cannot resolve JTROOT"
    exit 1
fi

cd "$JTROOT" || exit 1

if [[ -f "$SCRIPT_DIR/setprj.sh" ]]; then
    source "$SCRIPT_DIR/setprj.sh" >/dev/null
else
    export JTFRAME="$JTROOT/modules/jtframe"
    export CORES="$JTROOT/cores"
    export MODULES="$JTROOT/modules"
fi

KEEP_ARGS=()
STOP_ON_FAIL=0
TIMEOUT_SECS=600
DEFAULT_JOBS=4
JOBS="${DEFAULT_JOBS}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep)
            KEEP_ARGS+=("--keep")
            ;;
        --stop-on-fail)
            STOP_ON_FAIL=1
            ;;
        --timeout)
            shift
            TIMEOUT_SECS="$1"
            ;;
        --jobs|-j)
            shift
            JOBS="$1"
            ;;
        -h|--help)
            cat <<EOF
run_sdram_cache_simunits.sh: run burst/cache/cache-mux simunit regressions

Usage:
  modules/jtframe/bin/run_sdram_cache_simunits.sh [--keep] [--stop-on-fail] [--timeout SEC] [--jobs N]

Options:
  --keep          pass --keep to simunit.sh so waveforms are preserved
  --stop-on-fail  stop after the first failing test
  --timeout SEC   per-test timeout in seconds (default: 600)
  --jobs N        maximum number of tests to run in parallel (default: 4)
EOF
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

TESTS=(
    "modules/jtframe/ver/sdram/burst_sdram"
    "modules/jtframe/ver/sdram/burst_sdram_64mb"
    "modules/jtframe/ver/sdram/cache_burst_sdram"
    "modules/jtframe/ver/sdram/cache/read"
    "modules/jtframe/ver/sdram/cache/rw"
    "modules/jtframe/ver/sdram/cache/big_endian"
    "modules/jtframe/ver/sdram/cache/stress"
    "modules/jtframe/ver/sdram/cache/stress64-128"
    "modules/jtframe/ver/sdram/cache_mux/simple"
    "modules/jtframe/ver/sdram/cache_mux/rw"
    "modules/jtframe/ver/sdram/cache_mux/big_endian"
    "modules/jtframe/ver/sdram/cache_mux/stress"
)

LOG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jtframe-sdram-cache.XXXXXX")"
KEEP_LOG_ROOT=1
START_TS="$(date +%s)"
TOTAL_TESTS="${#TESTS[@]}"

PASS_LIST=()
FAIL_LIST=()
TIMEOUT_LIST=()
RUNNING_PIDS=()

declare -A TEST_BY_PID
declare -A STATUS_BY_PID
declare -A LOG_BY_PID

cleanup() {
    if [[ $KEEP_LOG_ROOT -eq 0 ]]; then
        rm -rf "$LOG_ROOT"
    fi
}

trap cleanup EXIT

sanitize_name() {
    echo "$1" | sed 's#^modules/jtframe/ver/sdram/##; s#[^A-Za-z0-9._-]#_#g'
}

remove_pid() {
    local target="$1"
    local next=()
    local pid
    for pid in "${RUNNING_PIDS[@]}"; do
        if [[ "$pid" != "$target" ]]; then
            next+=("$pid")
        fi
    done
    RUNNING_PIDS=("${next[@]}")
}

collect_result() {
    local pid="$1"
    local test_path="${TEST_BY_PID[$pid]}"
    local status_file="${STATUS_BY_PID[$pid]}"
    local log_file="${LOG_BY_PID[$pid]}"
    local status elapsed rc

    wait "$pid" 2>/dev/null || true
    remove_pid "$pid"

    if [[ ! -f "$status_file" ]]; then
        FAIL_LIST+=("$test_path")
        echo "[FAIL] $test_path (no status file) log: $log_file"
        return
    fi

    # shellcheck disable=SC1090
    source "$status_file"
    case "$status" in
        PASS)
            PASS_LIST+=("$test_path")
            echo "[PASS] $test_path (${elapsed}s)"
            ;;
        TIMEOUT)
            TIMEOUT_LIST+=("$test_path")
            FAIL_LIST+=("$test_path")
            echo "[FAIL] $test_path (${elapsed}s, timeout) log: $log_file"
            ;;
        *)
            FAIL_LIST+=("$test_path")
            echo "[FAIL] $test_path (${elapsed}s, rc=$rc) log: $log_file"
            ;;
    esac
}

poll_running_jobs() {
    local progress=0
    local pid
    for pid in "${RUNNING_PIDS[@]}"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            collect_result "$pid"
            progress=1
        fi
    done
    return "$progress"
}

wait_for_slot() {
    while [[ ${#RUNNING_PIDS[@]} -ge $JOBS ]]; do
        if ! poll_running_jobs; then
            sleep 1
        fi
        if [[ $STOP_ON_FAIL -eq 1 && ${#FAIL_LIST[@]} -gt 0 ]]; then
            return 1
        fi
    done
    return 0
}

run_test_bg() {
    local test_path="$1"
    local safe_name log_file status_file pid

    safe_name="$(sanitize_name "$test_path")"
    log_file="$LOG_ROOT/${safe_name}.log"
    status_file="$LOG_ROOT/${safe_name}.status"

    echo "[RUN ] $test_path"
    (
        local start_ts end_ts elapsed rc status
        start_ts="$(date +%s)"
        timeout --foreground "${TIMEOUT_SECS}s" \
            "$JTFRAME/bin/simunit.sh" --run "$test_path" "${KEEP_ARGS[@]}" \
            >"$log_file" 2>&1
        rc=$?
        end_ts="$(date +%s)"
        elapsed=$(( end_ts - start_ts ))
        if [[ $rc -eq 0 ]]; then
            status="PASS"
        elif [[ $rc -eq 124 ]]; then
            status="TIMEOUT"
        else
            status="FAIL"
        fi
        cat >"$status_file" <<EOF
status=$status
rc=$rc
elapsed=$elapsed
EOF
        exit 0
    ) &
    pid=$!
    RUNNING_PIDS+=("$pid")
    TEST_BY_PID["$pid"]="$test_path"
    STATUS_BY_PID["$pid"]="$status_file"
    LOG_BY_PID["$pid"]="$log_file"
}

for test_path in "${TESTS[@]}"; do
    if ! wait_for_slot; then
        break
    fi
    run_test_bg "$test_path"
done

while [[ ${#RUNNING_PIDS[@]} -gt 0 ]]; do
    if ! poll_running_jobs; then
        sleep 1
    fi
done

END_TS="$(date +%s)"
TOTAL_ELAPSED=$(( END_TS - START_TS ))

echo
echo "==> Summary"
echo "Total: $TOTAL_TESTS  Passed: ${#PASS_LIST[@]}  Failed: ${#FAIL_LIST[@]}  Elapsed: ${TOTAL_ELAPSED}s  Logs: $LOG_ROOT"

if [[ ${#PASS_LIST[@]} -gt 0 ]]; then
    echo
    echo "Passed:"
    printf '  %s\n' "${PASS_LIST[@]}"
fi

if [[ ${#TIMEOUT_LIST[@]} -gt 0 ]]; then
    echo
    echo "Timed out:"
    printf '  %s\n' "${TIMEOUT_LIST[@]}"
fi

if [[ ${#FAIL_LIST[@]} -gt 0 ]]; then
    echo
    echo "Failed:"
    printf '  %s\n' "${FAIL_LIST[@]}"
    exit 1
fi

KEEP_LOG_ROOT=0
exit 0
