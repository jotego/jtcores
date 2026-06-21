#!/bin/bash

main() {
    parse_args "$@"
    check_environment
    discover_cores
    discover_tasks
    if $LIST_ONLY; then
        print_task_list
        exit 0
    fi
    run_all_tasks
    print_summary
}

parse_args() {
    ROM_PATH="${HOME}/.mame/roms"
    KEEP_WORKDIR=false
    VERBOSE=false
    JOBS="${JTUTIL_SDRAM_TEST_JOBS:-1}"
    LIST_ONLY=false
    RUN_INDEX=""
    REQUESTED_SETNAME=""
    REQUESTED_CORES=()
    TASK_CORES=()
    TASK_SETNAMES=()
    TASK_RESULTS=()
    TASK_DETAILS=()

    while test $# -gt 0; do
        case "$1" in
            --core)
                shift
                if test -z "$1"; then
                    echo "[ERROR] --core requires an argument"
                    exit 1
                fi
                REQUESTED_CORES+=("$1")
                ;;
            --setname)
                shift
                if test -z "$1"; then
                    echo "[ERROR] --setname requires an argument"
                    exit 1
                fi
                REQUESTED_SETNAME="$1"
                ;;
            --rom-path)
                shift
                if test -z "$1"; then
                    echo "[ERROR] --rom-path requires an argument"
                    exit 1
                fi
                ROM_PATH="$1"
                ;;
            --keep)
                KEEP_WORKDIR=true
                ;;
            --jobs|-j)
                shift
                if test -z "$1"; then
                    echo "[ERROR] --jobs requires an argument"
                    exit 1
                fi
                JOBS="$1"
                ;;
            --jobs=*)
                JOBS="${1#*=}"
                ;;
            --list|--dry-run)
                LIST_ONLY=true
                ;;
            --verbose|-v)
                VERBOSE=true
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                echo "[ERROR] Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
        shift
    done

    if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
        echo "[ERROR] --jobs requires a positive integer"
        exit 1
    fi
}

check_environment() {
    if test -z "$JTROOT" || test -z "$JTFRAME"; then
        echo "[ERROR] JTROOT/JTFRAME are not defined. Run: source setprj.sh"
        exit 1
    fi
}

discover_cores() {
    CORE_LIST=()
    if test ${#REQUESTED_CORES[@]} -gt 0; then
        CORE_LIST=("${REQUESTED_CORES[@]}")
        return
    fi

    while IFS= read -r toml; do
        CORE_LIST+=("$(basename "$(dirname "$(dirname "$toml")")")")
    done < <(find "$JTROOT/cores" -mindepth 3 -maxdepth 3 -type f -path '*/cfg/mame2mra.toml' | sort)
}

discover_tasks() {
    local core
    local setname

    for core in "${CORE_LIST[@]}"; do
        if test -n "$REQUESTED_SETNAME"; then
            add_task "$core" "$REQUESTED_SETNAME"
            continue
        fi

        if ! test -d "$JTROOT/cores/$core" || core_marked_skip "$core" || ! core_uses_sdram "$core"; then
            add_task "$core" ""
            continue
        fi

        setname="$(get_main_setname "$core")"
        if test -n "$setname"; then
            add_task "$core" "$setname"
        else
            add_task "$core" ""
        fi
    done
}

add_task() {
    TASK_CORES+=("$1")
    TASK_SETNAMES+=("$2")
}

get_core_setnames() {
    local core="$1"
    local tmpbin
    local mra_file

    tmpbin="$(mktemp -d)"
    if JTBIN="$tmpbin" jtframe mra "$core" -o -n -g --path "$ROM_PATH" >/dev/null 2>&1; then
        find "$tmpbin/mra" -type f -name '*.mra' 2>/dev/null | sort | while IFS= read -r mra_file; do
            sed -n 's|.*<setname>\(.*\)</setname>.*|\1|p' "$mra_file" | head -n1
        done | sort -u
    fi
    rm -rf "$tmpbin"
}

get_main_setname() {
    local core="$1"
    local toml="$JTROOT/cores/$core/cfg/mame2mra.toml"
    local line
    local first
    local setname
    local tmpbin
    local mra_file

    if ! test -f "$toml"; then
        echo ""
        return
    fi

    line="$(grep -m1 'main_setnames[[:space:]]*=' "$toml")"
    if test -n "$line"; then
        first="$(echo "$line" | sed -E 's/.*main_setnames[[:space:]]*=[[:space:]]*\[([^\]]*)\].*/\1/' | grep -oE '"[^"]+"' | head -n1 | tr -d '"')"
        if test -n "$first"; then
            echo "$first"
            return
        fi
    fi

    tmpbin="$(mktemp -d)"
    if JTBIN="$tmpbin" jtframe mra "$core" -o -n -g --path "$ROM_PATH" >/dev/null 2>&1; then
        mra_file="$(find "$tmpbin/mra" -type f -name '*.mra' 2>/dev/null | sort | head -n1)"
        if test -n "$mra_file"; then
            setname="$(sed -n 's|.*<setname>\(.*\)</setname>.*|\1|p' "$mra_file" | head -n1)"
        fi
    fi
    rm -rf "$tmpbin"
    echo "$setname"
}

print_task_list() {
    local idx
    local setname

    echo "Discovered ${#TASK_CORES[@]} jtutil sdram validation tasks:"
    for idx in "${!TASK_CORES[@]}"; do
        setname="${TASK_SETNAMES[$idx]}"
        if test -n "$setname"; then
            echo " - ${TASK_CORES[$idx]}/$setname"
        else
            echo " - ${TASK_CORES[$idx]}"
        fi
    done
}


run_all_cores() {
    run_all_tasks
}

run_all_tasks() {
    WORKROOT="$(mktemp -d)"
    if ! $KEEP_WORKDIR; then
        trap 'rm -rf "$WORKROOT"' EXIT
    fi
    mkdir -p "$WORKROOT/locks"

    if test "$JOBS" -eq 1; then
        run_all_tasks_serial
    else
        run_all_tasks_parallel
    fi
}

run_all_tasks_serial() {
    local core
    local setname
    local status
    local idx

    for idx in "${!TASK_CORES[@]}"; do
        core="${TASK_CORES[$idx]}"
        setname="${TASK_SETNAMES[$idx]}"
        run_one_task "$core" "$setname"
        status=$?
        case $status in
            0) TASK_RESULTS+=("PASS") ;;
            2) TASK_RESULTS+=("SKIP") ;;
            *) TASK_RESULTS+=("FAIL") ;;
        esac
    done
}

run_all_tasks_parallel() {
    local idx
    local active=0
    local pid
    local pids=()
    local status
    local detail
    local out_file

    echo "[INFO] Running up to $JOBS jobs in parallel"

    for idx in "${!TASK_CORES[@]}"; do
        run_one_task_job "$idx" "${TASK_CORES[$idx]}" "${TASK_SETNAMES[$idx]}" &
        pids+=("$!")
        active=$((active+1))
        if test $active -ge "$JOBS"; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
            active=$((active-1))
        fi
    done

    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    for idx in "${!TASK_CORES[@]}"; do
        out_file="$WORKROOT/job-$idx.out"
        if test -s "$out_file"; then
            cat "$out_file"
        fi

        if test -f "$WORKROOT/job-$idx.status"; then
            status="$(cat "$WORKROOT/job-$idx.status")"
        else
            status=1
        fi
        case $status in
            0) TASK_RESULTS[$idx]="PASS" ;;
            2) TASK_RESULTS[$idx]="SKIP" ;;
            *) TASK_RESULTS[$idx]="FAIL" ;;
        esac

        if test -f "$WORKROOT/job-$idx.detail"; then
            detail="$(cat "$WORKROOT/job-$idx.detail")"
        else
            detail="${TASK_CORES[$idx]}/${TASK_SETNAMES[$idx]}|parallel job did not report a result"
        fi
        TASK_DETAILS[$idx]="$detail"
    done
}

run_one_task_job() {
    local idx="$1"
    local core="$2"
    local setname="$3"
    local status

    (
        RUN_INDEX="$idx"
        run_one_task "$core" "$setname"
        status=$?
        printf '%s\n' "$status" >"$WORKROOT/job-$idx.status"
        printf '%s\n' "$RUN_DETAIL" >"$WORKROOT/job-$idx.detail"
        exit 0
    ) >"$WORKROOT/job-$idx.out" 2>&1
}

run_one_task() {
    local core="$1"
    local setname="$2"
    local lock_dir=""
    local status

    RUN_DETAIL=""
    if ! test -d "$JTROOT/cores/$core"; then
        record_task_detail "$core" "$setname" "missing core directory"
        echo "[FAIL] $core - missing core directory"
        return 1
    fi
    if core_marked_skip "$core"; then
        record_task_detail "$core" "$setname" "JTFRAME_SKIP enabled"
        echo "[SKIP] $core - JTFRAME_SKIP enabled"
        return 2
    fi
    if ! core_uses_sdram "$core"; then
        record_task_detail "$core" "$setname" "core does not define SDRAM banks/cache lanes in mem.yaml"
        echo "[SKIP] $core - no SDRAM banks/cache lanes in mem.yaml"
        return 2
    fi
    if test -z "$setname"; then
        record_task_detail "$core" "$setname" "no setnames found"
        echo "[SKIP] $core - no setnames found"
        return 2
    fi

    if test "$JOBS" -gt 1; then
        lock_dir="$(acquire_setname_lock "$setname")"
    fi
    run_one_task_body "$core" "$setname"
    status=$?
    release_lock "$lock_dir"
    return $status
}

run_one_task_body() {
    local core="$1"
    local setname="$2"
    local ver_dir
    local core_work
    local job_jtbin
    local macro_undefs
    local jtsim_log
    local jtutil_log
    local jtutil_rc

    core_work="$WORKROOT/$core-$setname"
    if test -n "$RUN_INDEX"; then
        core_work="$WORKROOT/job-$RUN_INDEX-$core-$setname"
    fi
    mkdir -p "$core_work/sim" "$core_work/jtutil"

    job_jtbin=""
    if test "$JOBS" -gt 1; then
        job_jtbin="$core_work/jtbin"
        mkdir -p "$job_jtbin"
    fi
    macro_undefs="$(get_mister_undefs "$core")"

    echo "[INFO] $core -> $setname"

    rm -f "$JTROOT/rom/$setname.rom"
    if ! generate_rom_for_set "$core" "$setname" "$job_jtbin"; then
        record_task_detail "$core" "$setname" "jtframe mra failed"
        echo "[FAIL] $core - jtframe mra failed"
        return 1
    fi
    if ! test -f "$JTROOT/rom/$setname.rom"; then
        record_task_detail "$core" "$setname" "ROM was not generated"
        echo "[SKIP] $core - ROM was not generated"
        return 2
    fi
    if ! generate_mem_for_core "$core" "$job_jtbin"; then
        record_task_detail "$core" "$setname" "jtframe mem failed"
        echo "[FAIL] $core - jtframe mem failed"
        return 1
    fi

    ver_dir="$JTROOT/cores/$core/ver/$setname"
    mkdir -p "$ver_dir"
    jtsim_log="$core_work/jtsim.log"

    if ! run_jtsim_load "$ver_dir" "$setname" "$jtsim_log" "$job_jtbin" "$macro_undefs"; then
        if grep -q "JTFRAME_WIDTH must be an integer" "$jtsim_log"; then
            record_task_detail "$core" "$setname" "missing width/macros for simulation target (see $jtsim_log)"
            echo "[SKIP] $core - missing width/macros for simulation target"
            return 2
        fi
        record_task_detail "$core" "$setname" "jtsim -load failed (see $jtsim_log)"
        echo "[FAIL] $core - jtsim -load failed"
        if $VERBOSE; then
            sed -n '1,120p' "$jtsim_log"
        fi
        return 1
    fi
    if ! save_banks "$ver_dir" "$core_work/sim"; then
        record_task_detail "$core" "$setname" "jtsim did not generate sdram_bank*.bin (see $jtsim_log)"
        echo "[SKIP] $core - jtsim did not generate sdram_bank*.bin"
        return 2
    fi

    jtutil_log="$core_work/jtutil.log"
    run_jtutil_sdram "$ver_dir" "$setname" "$jtutil_log" "$job_jtbin" "$macro_undefs"
    jtutil_rc=$?
    if test $jtutil_rc -ne 0; then
        if grep -q "does not support download address/data transforms" "$jtutil_log"; then
            record_task_detail "$core" "$setname" "unsupported mem.yaml transforms for jtutil sdram (see $jtutil_log)"
            echo "[SKIP] $core - unsupported mem.yaml transforms"
            return 2
        fi
        record_task_detail "$core" "$setname" "jtutil sdram failed (see $jtutil_log)"
        echo "[FAIL] $core - jtutil sdram failed"
        if $VERBOSE; then
            sed -n '1,120p' "$jtutil_log"
        fi
        return 1
    fi
    if ! save_banks "$ver_dir" "$core_work/jtutil"; then
        record_task_detail "$core" "$setname" "jtutil did not generate sdram_bank*.bin (see $jtutil_log)"
        echo "[SKIP] $core - jtutil did not generate sdram_bank*.bin"
        return 2
    fi

    if ! compare_bank_sets "$core_work/sim" "$core_work/jtutil" "$core" "$setname"; then
        record_task_detail "$core" "$setname" "bank mismatch"
        echo "[FAIL] $core - bank mismatch"
        return 1
    fi

    record_task_detail "$core" "$setname" "validated"
    echo "[PASS] $core - $setname"
    return 0
}

record_task_detail() {
    local core="$1"
    local setname="$2"
    local detail="$3"

    if test -n "$setname"; then
        RUN_DETAIL="$core/$setname|$detail"
    else
        RUN_DETAIL="$core|$detail"
    fi
    TASK_DETAILS+=("$RUN_DETAIL")
}

acquire_setname_lock() {
    local setname="$1"
    local lock_dir="$WORKROOT/locks/$(safe_name "$setname")"

    while ! mkdir "$lock_dir" 2>/dev/null; do
        sleep 1
    done
    echo "$lock_dir"
}

release_lock() {
    local lock_dir="$1"

    if test -n "$lock_dir"; then
        rmdir "$lock_dir"
    fi
}

safe_name() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9_.-' '_'
}

core_marked_skip() {
    local core="$1"
    local macro_bash

    if ! macro_bash="$(jtframe cfgstr "$core" --output bash --target mister --def JTFRAME_WIDTH=320,JTFRAME_HEIGHT=240 2>/dev/null)"; then
        return 1
    fi

    (
        eval "$macro_bash" >/dev/null 2>&1
        test -n "$JTFRAME_SKIP"
    )
}

core_uses_sdram() {
    local core="$1"
    local mem_file="$JTROOT/cores/$core/cfg/mem.yaml"
    local banks_len
    local cache_len

    if ! test -f "$mem_file"; then
        return 1
    fi
    banks_len="$(yq -r '.sdram.banks // [] | length' "$mem_file" 2>/dev/null)"
    cache_len="$(yq -r '.sdram."cache-lanes" // [] | length' "$mem_file" 2>/dev/null)"
    if test -z "$banks_len" || test "$banks_len" = "null"; then
        banks_len=0
    fi
    if test -z "$cache_len" || test "$cache_len" = "null"; then
        cache_len=0
    fi
    test $((banks_len + cache_len)) -gt 0
}

get_mister_undefs() {
    local core="$1"
    local err_file

    err_file="$(mktemp)"
    if jtframe cfgstr "$core" --output bash --target mister --def JTFRAME_WIDTH=320,JTFRAME_HEIGHT=240 >/dev/null 2>"$err_file"; then
        rm -f "$err_file"
        return
    fi
    if grep -q "cannot define both JTFRAME_SDRAM_XL and JTFRAME_SDRAM_LARGE" "$err_file"; then
        echo "JTFRAME_SDRAM_LARGE"
    fi
    rm -f "$err_file"
}

generate_rom_for_set() {
    local core="$1"
    local setname="$2"
    local job_jtbin="$3"
    if test -n "$job_jtbin"; then
        if $VERBOSE; then
            JTBIN="$job_jtbin" jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH"
        else
            JTBIN="$job_jtbin" jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH" >/dev/null 2>&1
        fi
    elif $VERBOSE; then
        jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH"
    else
        jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH" >/dev/null 2>&1
    fi
}

generate_mem_for_core() {
    local core="$1"
    local job_jtbin="$2"
    if test -n "$job_jtbin"; then
        if $VERBOSE; then
            JTBIN="$job_jtbin" jtframe mem "$core" --target mister
        else
            JTBIN="$job_jtbin" jtframe mem "$core" --target mister >/dev/null 2>&1
        fi
    elif $VERBOSE; then
        jtframe mem "$core" --target mister
    else
        jtframe mem "$core" --target mister >/dev/null 2>&1
    fi
}

run_jtsim_load() {
    local ver_dir="$1"
    local setname="$2"
    local log_file="$3"
    local job_jtbin="$4"
    local macro_undefs="$5"
    local args
    local undef

    args=(-batch -mr -load -setname "$setname")
    for undef in $macro_undefs; do
        args+=(-u "$undef")
    done
    (
        cd "$ver_dir" || exit 1
        if test -n "$job_jtbin"; then
            export JTBIN="$job_jtbin"
        fi
        rm -f sdram*.bin
        jtsim "${args[@]}"
    ) >"$log_file" 2>&1
}

save_banks() {
    local src_dir="$1"
    local dst_dir="$2"
    local found=false
    local f

    rm -f "$dst_dir"/sdram*.bin
    for f in "$src_dir"/sdram*.bin; do
        if test -f "$f"; then
            cp "$f" "$dst_dir/"
            found=true
        fi
    done
    $found
}

run_jtutil_sdram() {
    local ver_dir="$1"
    local setname="$2"
    local log_file="$3"
    local job_jtbin="$4"
    local macro_undefs="$5"
    local args
    local undef

    args=(sdram --target mister "$setname")
    for undef in $macro_undefs; do
        args+=(-u "$undef")
    done
    (
        cd "$ver_dir" || exit 1
        if test -n "$job_jtbin"; then
            export JTBIN="$job_jtbin"
        fi
        rm -f sdram*.bin
        jtutil "${args[@]}"
    ) >"$log_file" 2>&1
}

compare_bank_sets() {
    local sim_dir="$1"
    local jtutil_dir="$2"
    local core="$3"
    local setname="$4"
    local bank

    for bank in sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin \
                sdram2_bank0.bin sdram2_bank1.bin sdram2_bank2.bin sdram2_bank3.bin; do
        if test -f "$sim_dir/$bank" || test -f "$jtutil_dir/$bank"; then
            if ! compare_bank_file "$sim_dir/$bank" "$jtutil_dir/$bank"; then
                echo "[DIFF] $core/$setname mismatch in $bank"
                return 1
            fi
        fi
    done
    return 0
}

compare_bank_file() {
    local sim_file="$1"
    local jtutil_file="$2"

    if test -f "$sim_file" && test -f "$jtutil_file"; then
        cmp -s "$sim_file" "$jtutil_file"
        return $?
    fi
    if test -f "$sim_file"; then
        file_is_zero "$sim_file"
        return $?
    fi
    if test -f "$jtutil_file"; then
        file_is_zero "$jtutil_file"
        return $?
    fi
    return 0
}

file_is_zero() {
    local file="$1"
    local size

    size="$(stat -c '%s' "$file")" || return 1
    cmp -s "$file" <(head -c "$size" /dev/zero)
}

print_summary() {
    local idx=0
    local pass=0
    local fail=0
    local skip=0

    echo ""
    echo "========== jtutil sdram verifier summary =========="
    while test $idx -lt ${#TASK_CORES[@]}; do
        echo " - ${TASK_RESULTS[$idx]} ${TASK_DETAILS[$idx]}"
        case "${TASK_RESULTS[$idx]}" in
            PASS) pass=$((pass+1)) ;;
            FAIL) fail=$((fail+1)) ;;
            SKIP) skip=$((skip+1)) ;;
        esac
        idx=$((idx+1))
    done
    echo "Totals: pass=$pass fail=$fail skip=$skip"
    echo "Workdir: $WORKROOT"

    if test $fail -gt 0; then
        exit 1
    fi
}

print_help() {
    cat <<'EOF'
Usage: jtutil-sdram-test.sh [options]

Run jtsim-based SDRAM generation and compare against jtutil sdram output.
By default, the script scans all cores with cfg/mame2mra.toml.

Options:
    --core <name>        Test one core (can be repeated)
    --setname <setname>  Force one setname instead of discovering core setnames
    --rom-path <path>    Path to MAME zip files (default: ~/.mame/roms)
    --keep               Keep temporary workdir
    -j, --jobs <n>       Run up to n core/set simulations in parallel.
                         Default: JTUTIL_SDRAM_TEST_JOBS, or 1 when unset.
                         Parallel jobs use separate temporary JTBIN folders.
    --list, --dry-run    Print discovered core/set tasks without running simulations
    -v, --verbose        Show command outputs
    -h, --help           Show this help
EOF
}

main "$@"
