#!/bin/bash

main() {
    parse_args "$@"
    check_environment
    discover_cores
    run_all_cores
    print_summary
}

parse_args() {
    ROM_PATH="${HOME}/.mame/roms"
    KEEP_WORKDIR=false
    VERBOSE=false
    JOBS=1
    REQUESTED_SETNAME=""
    REQUESTED_CORES=()
    CORE_RESULTS=()
    CORE_DETAILS=()

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

run_all_cores() {
    WORKROOT="$(mktemp -d)"
    if ! $KEEP_WORKDIR; then
        trap 'rm -rf "$WORKROOT"' EXIT
    fi

    if test "$JOBS" -eq 1; then
        run_all_cores_serial
    else
        run_all_cores_parallel
    fi
}

run_all_cores_serial() {
    local core
    local status

    for core in "${CORE_LIST[@]}"; do
        run_one_core "$core"
        status=$?
        case $status in
            0) CORE_RESULTS+=("PASS") ;;
            2) CORE_RESULTS+=("SKIP") ;;
            *) CORE_RESULTS+=("FAIL") ;;
        esac
    done
}

run_all_cores_parallel() {
    local idx
    local active=0
    local pid
    local pids=()
    local status
    local detail
    local out_file

    echo "[INFO] Running up to $JOBS jobs in parallel"

    for idx in "${!CORE_LIST[@]}"; do
        run_one_core_job "$idx" "${CORE_LIST[$idx]}" &
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

    for idx in "${!CORE_LIST[@]}"; do
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
            0) CORE_RESULTS[$idx]="PASS" ;;
            2) CORE_RESULTS[$idx]="SKIP" ;;
            *) CORE_RESULTS[$idx]="FAIL" ;;
        esac

        if test -f "$WORKROOT/job-$idx.detail"; then
            detail="$(cat "$WORKROOT/job-$idx.detail")"
        else
            detail="${CORE_LIST[$idx]}|parallel job did not report a result"
        fi
        CORE_DETAILS[$idx]="$detail"
    done
}

run_one_core_job() {
    local idx="$1"
    local core="$2"
    local status

    (
        RUN_INDEX="$idx"
        run_one_core "$core"
        status=$?
        printf '%s\n' "$status" >"$WORKROOT/job-$idx.status"
        printf '%s\n' "$RUN_DETAIL" >"$WORKROOT/job-$idx.detail"
        exit 0
    ) >"$WORKROOT/job-$idx.out" 2>&1
}

run_one_core() {
    local core="$1"
    local setname
    local ver_dir
    local core_work
    local jtsim_log
    local jtutil_log
    local jtutil_rc

    RUN_DETAIL=""
    if ! test -d "$JTROOT/cores/$core"; then
        record_core_detail "$core" "missing core directory"
        echo "[FAIL] $core - missing core directory"
        return 1
    fi
    if core_marked_skip "$core"; then
        record_core_detail "$core" "JTFRAME_SKIP enabled"
        echo "[SKIP] $core - JTFRAME_SKIP enabled"
        return 2
    fi
    if ! core_uses_sdram "$core"; then
        record_core_detail "$core" "core does not define SDRAM banks in mem.yaml"
        echo "[SKIP] $core - no SDRAM banks in mem.yaml"
        return 2
    fi

    setname="$REQUESTED_SETNAME"
    if test -z "$setname"; then
        setname="$(get_main_setname "$core")"
    fi
    if test -z "$setname"; then
        record_core_detail "$core" "no main setname found"
        echo "[SKIP] $core - no main setname found"
        return 2
    fi

    echo "[INFO] $core -> $setname"

    rm -f "$JTROOT/rom/$setname.rom"
    if ! generate_rom_for_set "$core" "$setname"; then
        record_core_detail "$core" "jtframe mra failed for $setname"
        echo "[FAIL] $core - jtframe mra failed"
        return 1
    fi
    if ! test -f "$JTROOT/rom/$setname.rom"; then
        record_core_detail "$core" "ROM was not generated for $setname"
        echo "[SKIP] $core - ROM was not generated"
        return 2
    fi
    if ! generate_mem_for_core "$core"; then
        record_core_detail "$core" "jtframe mem failed"
        echo "[FAIL] $core - jtframe mem failed"
        return 1
    fi

    ver_dir="$JTROOT/cores/$core/ver/$setname"
    mkdir -p "$ver_dir"
    core_work="$WORKROOT/$core-$setname"
    if test -n "$RUN_INDEX"; then
        core_work="$WORKROOT/job-$RUN_INDEX-$core-$setname"
    fi
    mkdir -p "$core_work/sim" "$core_work/jtutil"
    jtsim_log="$core_work/jtsim.log"

    if ! run_jtsim_load "$ver_dir" "$setname" "$jtsim_log"; then
        if grep -q "JTFRAME_WIDTH must be an integer" "$jtsim_log"; then
            record_core_detail "$core" "missing width/macros for simulation target"
            echo "[SKIP] $core - missing width/macros for simulation target"
            return 2
        fi
        record_core_detail "$core" "jtsim -load failed for $setname (see $jtsim_log)"
        echo "[FAIL] $core - jtsim -load failed"
        if $VERBOSE; then
            sed -n '1,120p' "$jtsim_log"
        fi
        return 1
    fi
    if ! save_banks "$ver_dir" "$core_work/sim"; then
        record_core_detail "$core" "jtsim did not generate sdram_bank*.bin"
        echo "[SKIP] $core - jtsim did not generate sdram_bank*.bin"
        return 2
    fi

    jtutil_log="$core_work/jtutil.log"
    run_jtutil_sdram "$ver_dir" "$setname" "$jtutil_log"
    jtutil_rc=$?
    if test $jtutil_rc -ne 0; then
        if grep -q "does not support download address/data transforms" "$jtutil_log"; then
            record_core_detail "$core" "unsupported mem.yaml transforms for jtutil sdram"
            echo "[SKIP] $core - unsupported mem.yaml transforms"
            return 2
        fi
        record_core_detail "$core" "jtutil sdram failed for $setname"
        echo "[FAIL] $core - jtutil sdram failed"
        if $VERBOSE; then
            sed -n '1,120p' "$jtutil_log"
        fi
        return 1
    fi
    if ! save_banks "$ver_dir" "$core_work/jtutil"; then
        record_core_detail "$core" "jtutil did not generate sdram_bank*.bin"
        echo "[SKIP] $core - jtutil did not generate sdram_bank*.bin"
        return 2
    fi

    if ! compare_bank_sets "$core_work/sim" "$core_work/jtutil" "$core" "$setname"; then
        record_core_detail "$core" "bank mismatch for $setname"
        echo "[FAIL] $core - bank mismatch"
        return 1
    fi

    record_core_detail "$core" "$setname"
    echo "[PASS] $core - $setname"
    return 0
}

record_core_detail() {
    local core="$1"
    local detail="$2"

    RUN_DETAIL="$core|$detail"
    CORE_DETAILS+=("$RUN_DETAIL")
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

    if ! test -f "$mem_file"; then
        return 1
    fi
    banks_len="$(yq -r '.sdram.banks | length' "$mem_file" 2>/dev/null)"
    if test -z "$banks_len" || test "$banks_len" = "null"; then
        return 1
    fi
    test "$banks_len" -gt 0
}

generate_rom_for_set() {
    local core="$1"
    local setname="$2"
    if $VERBOSE; then
        jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH"
    else
        jtframe mra "$core" -o --setname "$setname" --path "$ROM_PATH" >/dev/null 2>&1
    fi
}

generate_mem_for_core() {
    local core="$1"
    if $VERBOSE; then
        jtframe mem "$core"
    else
        jtframe mem "$core" >/dev/null 2>&1
    fi
}

run_jtsim_load() {
    local ver_dir="$1"
    local setname="$2"
    local log_file="$3"
    (
        cd "$ver_dir" || exit 1
        rm -f sdram*.bin
        jtsim -batch -mr -load -setname "$setname"
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
    (
        cd "$ver_dir" || exit 1
        rm -f sdram*.bin
        jtutil sdram "$setname"
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
    while test $idx -lt ${#CORE_LIST[@]}; do
        echo " - ${CORE_RESULTS[$idx]} ${CORE_DETAILS[$idx]}"
        case "${CORE_RESULTS[$idx]}" in
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
    --setname <setname>  Force setname instead of using main_setnames
    --rom-path <path>    Path to MAME zip files (default: ~/.mame/roms)
    --keep               Keep temporary workdir
    -j, --jobs <n>       Run up to n core/set simulations in parallel (default: 1)
    -v, --verbose        Show command outputs
    -h, --help           Show this help
EOF
}

main "$@"
