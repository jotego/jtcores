#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: sim.sh [--baseline-dir DIR] [--baseline-sha SHA] [--candidate-dir DIR]
              [--build-dir DIR] [--run-staged DIR] [--mode legacy|passive]
              [--geometry 400x262|384x260|384x261] [--scenario pattern_a|service|features|legacy_formats|copy_first|copy_read_before|irq_hv|geometry_switch|production_switch]
              [--copy-start active|late] [--transitions]
              [--dry-run] [--keep] [-- program arguments ...]

Compile and run the timed YM7101 legacy/current comparison bench with Verilator.
The passive bench and candidate sources are snapshotted into the external build
directory; baseline HDL is taken from the explicitly identified source tree and
renamed there so both implementations can be elaborated together.

Defaults:
  baseline: /nobackup/tasks/jtcores-180/baseline/source (SHA 3dc6b88e...)
  candidate: cores/s18/hdl in this checkout (including ym7101_raster.v)
  frame timing: $JTFRAME/hdl/video/jtframe_vtimer.v
  production S16 timing: cores/s16/hdl/jts16_vtimer.v
  build: /nobackup/tasks/jtcores-180/render

Set JTFRAME by sourcing setprj.sh before running this script.
EOF
}

die() {
    echo "sim.sh: $*" >&2
    exit 2
}

resolve_path() {
    realpath "$1"
}

baseline_identity() {
    local dir=$1
    local identity
    if [[ -f "$dir/HEAD" ]]; then
        identity=$(tr -d '[:space:]' < "$dir/HEAD")
    elif identity=$(git -C "$dir" rev-parse --verify HEAD 2>/dev/null); then
        :
    else
        die "baseline tree needs a HEAD file or a git worktree: $dir"
    fi
    printf '%s\n' "$identity"
}

rename_baseline_modules() {
    local input=$1 output=$2 list name tmp
    mkdir -p "$(dirname "$output")"
    cp "$input" "$output"
    tmp="${output}.tmp"
    list=$(sed -nE 's/^[[:space:]]*module[[:space:]]+([[:alnum:]_$]+).*/\1/p' \
        "$BASELINE_DIR/cores/s18/hdl/ym7101.v" \
        "$BASELINE_DIR/cores/s18/hdl/ym_lib.v" \
        "$BASELINE_DIR/cores/s18/hdl/vram.sv" | sort -u)
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        sed -E "s/\\b${name}\\b/${name}_legacy/g" "$output" > "$tmp"
        mv "$tmp" "$output"
    done <<< "$list"
}

write_manifest() {
    local src=$1 dir=$2
    {
        echo "baseline_sha=$BASELINE_SHA"
        echo "baseline_dir=$BASELINE_DIR"
        echo "candidate_dir=$CANDIDATE_DIR"
        echo "candidate_git_head=$(git -C "$REPO" rev-parse HEAD)"
        echo "runner=$RUNNER_DIR/sim.sh"
        echo "runner_sha256=$(sha256sum "$RUNNER_DIR/sim.sh" | awk '{print $1}')"
        echo "jtframe_vtimer=$JTFRAME_VTIMER"
        echo "jts16_vtimer=$S16_VTIMER"
        echo "bench=$BENCH"
        echo "test_mode=$TEST_MODE"
        echo "geometry=$GEOMETRY"
        echo "scenario=$SCENARIO"
        echo "cpu_start_delay96=$CPU_START_DELAY96"
        echo "copy_first_start=$COPY_START"
        if ((TRANSITIONS)); then echo "transitions=enabled"; else echo "transitions=disabled"; fi
        echo "verilator=$(verilator --version)"
        echo "build_jobs=$BUILD_JOBS"
        echo "source_sha256:"
        (cd "$src" && sha256sum test.v geometry_switch_vtimer.v service_profile.vh irq_hv_profile.vh features_profile.vh legacy_formats.vh README.md test.cpp candidate_ym7101.v candidate_ym_lib.v candidate_vram.sv candidate_ym7101_raster.v candidate_jtframe_vtimer.v candidate_jts16_vtimer.v \
            baseline_ym7101.v baseline_ym_lib.v baseline_vram.sv)
    } > "$dir/manifest.txt"
    cat "$dir/manifest.txt"
}

verify_staged_snapshot() {
    local dir=$1 manifest=$1/manifest.txt src=$1/src
    [[ -f "$manifest" && -d "$src" ]] || die "staged snapshot needs manifest.txt and src/: $dir"
    grep -Fxq "baseline_sha=$BASELINE_SHA" "$manifest" || die "staged baseline SHA does not match $BASELINE_SHA"
    grep -Fxq "test_mode=$TEST_MODE" "$manifest" || die "staged test mode does not match $TEST_MODE"
    grep -Fxq "geometry=$GEOMETRY" "$manifest" || die "staged geometry does not match $GEOMETRY"
    grep -Fxq "scenario=$SCENARIO" "$manifest" || die "staged scenario does not match $SCENARIO"
    grep -Fxq "cpu_start_delay96=$CPU_START_DELAY96" "$manifest" || die "staged CPU startup phase does not match K=$CPU_START_DELAY96"
    grep -Fxq "copy_first_start=$COPY_START" "$manifest" || die "staged copy-first selector does not match $COPY_START"
    if ((TRANSITIONS)); then
        grep -Fxq "transitions=enabled" "$manifest" || die "staged transition setting does not match"
    else
        grep -Fxq "transitions=disabled" "$manifest" || die "staged transition setting does not match"
    fi
    awk 'seen { print } /^source_sha256:$/ { seen=1 }' "$manifest" | (cd "$src" && sha256sum -c -) || die "staged source hash verification failed: $dir"
}

build_runner() {
    local src=$1 obj=$2
    local -a defines=("-D$TEST_MODE" -DSIMULATION -DJTFRAME_MCLK=48000000)
    case "$GEOMETRY" in
        400x262) ;;
        384x260) defines+=(-DPASSIVE_384_260) ;;
        384x261) defines+=(-DPASSIVE_384_261) ;;
    esac
    if ((TRANSITIONS)); then defines+=(-DPASSIVE_TRANSITIONS); fi
    if [[ "$SCENARIO" == service ]]; then defines+=(-DSERVICE_SCENARIO); fi
    if [[ "$SCENARIO" == features ]]; then defines+=(-DFEATURES_SCENARIO); fi
    if [[ "$SCENARIO" == legacy_formats ]]; then defines+=(-DLEGACY_FORMATS_TEST); fi
    if [[ "$SCENARIO" == copy_first ]]; then defines+=(-DSERVICE_COPY_FIRST); fi
    if [[ "$SCENARIO" == copy_read_before ]]; then defines+=(-DSERVICE_SCENARIO -DSERVICE_COPY_READ_BEFORE); fi
    if [[ "$SCENARIO" == irq_hv ]]; then defines+=(-DIRQ_HV_SCENARIO); fi
    if [[ "$SCENARIO" == geometry_switch ]]; then defines+=(-DGEOMETRY_SWITCH_SCENARIO); fi
    if [[ "$SCENARIO" == production_switch ]]; then defines+=(-DGEOMETRY_SWITCH_SCENARIO -DPRODUCTION_TIMER_SCENARIO); fi
    mkdir -p "$obj"
    verilator --quiet --cc --exe --build --build-jobs "$BUILD_JOBS" --timing --trace-fst \
        --top-module test --Mdir "$obj" -Wno-fatal -Wno-TIMESCALEMOD \
        "${defines[@]}" -I"$JTFRAME/ver/inc" -I"$src" \
        "$src/test.v" "$src/geometry_switch_vtimer.v" "$src/candidate_ym7101.v" "$src/candidate_ym_lib.v" "$src/candidate_vram.sv" \
        "$src/candidate_ym7101_raster.v" "$src/candidate_jtframe_vtimer.v" "$src/candidate_jts16_vtimer.v" \
        "$src/baseline_ym7101.v" "$src/baseline_ym_lib.v" "$src/baseline_vram.sv" \
        "$src/test.cpp"
}

main() {
    local base_default=/nobackup/tasks/jtcores-180/baseline/source
    local sha_default=3dc6b88e0204fd3abbb462b34f428757f8596e94
    local build_default=/nobackup/tasks/jtcores-180/render
    local started status dry_run=0 use_staged=0
    local -a run_args=()
    local COPY_START=active COPY_START_EXPLICIT=0
    REPO=$(git rev-parse --show-toplevel)
    RUNNER_DIR=$(cd "$(dirname "$0")" && pwd)
    BASELINE_DIR=${YM7101_BASELINE_DIR:-$base_default}
    BASELINE_SHA=${YM7101_BASELINE_SHA:-$sha_default}
    CANDIDATE_DIR=${YM7101_CANDIDATE_DIR:-$REPO/cores/s18/hdl}
    BUILD_DIR=${YM7101_RENDER_BUILD_DIR:-$build_default}
    TEST_MODE=${YM7101_RENDER_MODE:-LEGACY_TEST}
    BUILD_JOBS=${YM7101_RENDER_JOBS:-4}
    GEOMETRY=400x262
    TRANSITIONS=0
    SCENARIO=pattern_a
    CPU_START_DELAY96=0
    BENCH=$RUNNER_DIR/test.v

    while (($#)); do
        case "$1" in
            --baseline-dir) (($# >= 2)) || die "--baseline-dir needs a path"; BASELINE_DIR=$2; shift 2 ;;
            --baseline-sha) (($# >= 2)) || die "--baseline-sha needs a SHA"; BASELINE_SHA=$2; shift 2 ;;
            --candidate-dir) (($# >= 2)) || die "--candidate-dir needs a path"; CANDIDATE_DIR=$2; shift 2 ;;
            --build-dir) (($# >= 2)) || die "--build-dir needs a path"; BUILD_DIR=$2; shift 2 ;;
            --run-staged)
                (($# >= 2)) || die "--run-staged needs a build directory"
                BUILD_DIR=$2
                use_staged=1
                shift 2 ;;
            --mode)
                (($# >= 2)) || die "--mode needs legacy or passive"
                case "$2" in
                    legacy|LEGACY_TEST) TEST_MODE=LEGACY_TEST ;;
                    passive|PASSIVE_TEST) TEST_MODE=PASSIVE_TEST ;;
                    *) die "unknown mode '$2' (use legacy or passive)" ;;
                esac
                shift 2 ;;
            --geometry)
                (($# >= 2)) || die "--geometry needs 400x262, 384x260, or 384x261"
                case "$2" in
                    400x262|384x260|384x261) GEOMETRY=$2 ;;
                    *) die "unknown geometry '$2' (use 400x262, 384x260, or 384x261)" ;;
                esac
                shift 2 ;;
            --transitions) TRANSITIONS=1; shift ;;
            --scenario)
                (($# >= 2)) || die "--scenario needs pattern_a, service, features, legacy_formats, copy_first, copy_read_before, irq_hv, geometry_switch, or production_switch"
                case "$2" in
                    pattern_a|service|features|legacy_formats|copy_first|copy_read_before|irq_hv|geometry_switch|production_switch) SCENARIO=$2 ;;
                    *) die "unknown scenario '$2' (use pattern_a, service, features, legacy_formats, copy_first, copy_read_before, irq_hv, geometry_switch, or production_switch)" ;;
                esac
                shift 2 ;;
            --copy-start)
                (($# >= 2)) || die "--copy-start needs active or late"
                case "$2" in active|late) COPY_START=$2 ;; *) die "unknown copy start '$2' (use active or late)" ;; esac
                COPY_START_EXPLICIT=1
                shift 2 ;;
            --dry-run) dry_run=1; shift ;;
            --keep) run_args+=(--keep); shift ;;
            -h|--help) usage; return 0 ;;
            --) shift; run_args+=("$@"); break ;;
            -*) die "unknown option '$1' (use -- before program arguments)" ;;
            *) die "unexpected positional argument '$1' (use -- before program arguments)" ;;
        esac
    done

    [[ -n "${JTFRAME:-}" ]] || die "JTFRAME is unset; source modules/jtframe/bin/setprj.sh first"
    [[ "$BUILD_JOBS" =~ ^[1-4]$ ]] || die "YM7101_RENDER_JOBS must be between 1 and 4"
    JTFRAME_VTIMER=$JTFRAME/hdl/video/jtframe_vtimer.v
    S16_VTIMER=$REPO/cores/s16/hdl/jts16_vtimer.v
    [[ "$TEST_MODE" == LEGACY_TEST || "$TEST_MODE" == PASSIVE_TEST ]] || die "invalid mode: $TEST_MODE"
    for arg in "${run_args[@]}"; do
        [[ "$arg" != +copy_start=* ]] || die "+copy_start is reserved; use --copy-start"
    done
    if [[ "$GEOMETRY" != 400x262 || "$TRANSITIONS" == 1 ]] && [[ "$TEST_MODE" != PASSIVE_TEST ]]; then
        die "non-default geometry and transition coverage require passive mode"
    fi
    if [[ ( "$SCENARIO" == service || "$SCENARIO" == copy_first || "$SCENARIO" == copy_read_before ) && "$TRANSITIONS" == 1 ]]; then
        die "service/copy scenarios and reset transitions are separate bounded profiles"
    fi
    if [[ "$SCENARIO" == features && ( "$TEST_MODE" != PASSIVE_TEST || "$TRANSITIONS" == 1 ) ]]; then
        die "features scenario requires passive mode without reset transitions"
    fi
    if [[ "$SCENARIO" == legacy_formats && ( "$TEST_MODE" != LEGACY_TEST || "$GEOMETRY" != 400x262 || "$TRANSITIONS" == 1 ) ]]; then
        die "legacy_formats scenario requires legacy mode, 400x262 geometry, and no reset transitions"
    fi
    if [[ "$SCENARIO" == irq_hv && "$TRANSITIONS" == 1 ]]; then
        die "irq_hv does not combine with reset transitions"
    fi
    if [[ "$SCENARIO" == irq_hv && "$TEST_MODE" == PASSIVE_TEST && "$GEOMETRY" == 384x261 ]]; then
        die "irq_hv passive coverage is defined for 400x262 and 384x260"
    fi
    if [[ "$SCENARIO" == irq_hv && "$TEST_MODE" == LEGACY_TEST && "$GEOMETRY" != 400x262 ]]; then
        die "irq_hv legacy equivalence requires 400x262 geometry"
    fi
    if [[ "$SCENARIO" == geometry_switch && ( "$TEST_MODE" != PASSIVE_TEST || "$GEOMETRY" != 400x262 || "$TRANSITIONS" == 1 ) ]]; then
        die "geometry_switch requires passive mode, 400x262 start geometry, and no reset transitions"
    fi
    if [[ "$SCENARIO" == production_switch && ( "$TEST_MODE" != PASSIVE_TEST || "$GEOMETRY" != 400x262 || "$TRANSITIONS" == 1 ) ]]; then
        die "production_switch requires passive mode, default 400x262 test setup, and no reset transitions"
    fi
    if ((COPY_START_EXPLICIT)) && [[ "$SCENARIO" != copy_first ]]; then
        die "--copy-start is only valid with --scenario copy_first"
    fi
    if [[ "$SCENARIO" == copy_first ]]; then
        [[ "$GEOMETRY" != 384x261 ]] || die "copy_first is not validated for 384x261 geometry"
        if [[ "$COPY_START" == late ]]; then
            [[ "$TEST_MODE" == PASSIVE_TEST ]] || die "late copy start is only supported in passive mode"
            [[ "$GEOMETRY" != 384x261 ]] || die "late copy start is not validated for 384x261 geometry"
        fi
        run_args+=("+copy_start=$COPY_START")
    fi
    if [[ "$SCENARIO" == copy_read_before && ( "$TEST_MODE" != LEGACY_TEST || "$GEOMETRY" != 400x262 ) ]]; then
        die "copy_read_before is a legacy-only diagnostic at 400x262"
    fi
    CPU_START_DELAY96=0
    if [[ "$TEST_MODE" == PASSIVE_TEST && "$GEOMETRY" == 384x260 && "$SCENARIO" == irq_hv ]]; then
        CPU_START_DELAY96=2
    fi
    command -v verilator >/dev/null || die "verilator not found"
    BASELINE_DIR=$(resolve_path "$BASELINE_DIR")
    CANDIDATE_DIR=$(resolve_path "$CANDIDATE_DIR")
    BUILD_DIR=$(mkdir -p "$BUILD_DIR" && resolve_path "$BUILD_DIR")
    command -v flock >/dev/null || die "flock not found; cannot protect build directory"
    exec {BUILD_LOCK_FD}>>"$BUILD_DIR/.sim.lock"
    if ! flock -n "$BUILD_LOCK_FD"; then
        die "build directory is already in use: $BUILD_DIR"
    fi
    [[ -f "$BENCH" ]] || die "missing shared fixture bench: $BENCH"
    [[ -f "$BASELINE_DIR/cores/s18/hdl/ym7101.v" && -f "$BASELINE_DIR/cores/s18/hdl/ym_lib.v" && -f "$BASELINE_DIR/cores/s18/hdl/vram.sv" ]] || die "baseline tree is incomplete: $BASELINE_DIR"
    [[ -f "$JTFRAME_VTIMER" ]] || die "missing jtframe video timer: $JTFRAME_VTIMER"
    [[ -f "$S16_VTIMER" ]] || die "missing production S16 timer: $S16_VTIMER"
    if ((!use_staged)); then
        [[ -f "$CANDIDATE_DIR/ym7101.v" && -f "$CANDIDATE_DIR/ym_lib.v" && -f "$CANDIDATE_DIR/vram.sv" && -f "$CANDIDATE_DIR/ym7101_raster.v" ]] || die "candidate tree needs ym7101.v, ym_lib.v, vram.sv and ym7101_raster.v"
    fi
    local actual_sha
    actual_sha=$(baseline_identity "$BASELINE_DIR")
    [[ "$actual_sha" == "$BASELINE_SHA" ]] || die "baseline identity mismatch: requested $BASELINE_SHA, tree says $actual_sha"
    BASELINE_SHA=$actual_sha

    local src=$BUILD_DIR/src
    started=$SECONDS
    if ((use_staged)); then
        verify_staged_snapshot "$BUILD_DIR"
    else
        mkdir -p "$src"
        cp "$BENCH" "$src/test.v"
        cp "$(dirname "$0")/service_profile.vh" "$src/service_profile.vh"
        cp "$(dirname "$0")/irq_hv_profile.vh" "$src/irq_hv_profile.vh"
        cp "$(dirname "$0")/features_profile.vh" "$src/features_profile.vh"
        cp "$(dirname "$0")/legacy_formats.vh" "$src/legacy_formats.vh"
        cp "$(dirname "$0")/README.md" "$src/README.md"
        cp "$(dirname "$0")/test.cpp" "$src/test.cpp"
        cp "$(dirname "$0")/geometry_switch_vtimer.v" "$src/geometry_switch_vtimer.v"
        cp "$CANDIDATE_DIR/ym7101.v" "$src/candidate_ym7101.v"
        cp "$CANDIDATE_DIR/ym_lib.v" "$src/candidate_ym_lib.v"
        cp "$CANDIDATE_DIR/vram.sv" "$src/candidate_vram.sv"
        cp "$CANDIDATE_DIR/ym7101_raster.v" "$src/candidate_ym7101_raster.v"
        cp "$JTFRAME_VTIMER" "$src/candidate_jtframe_vtimer.v"
        cp "$S16_VTIMER" "$src/candidate_jts16_vtimer.v"
        rename_baseline_modules "$BASELINE_DIR/cores/s18/hdl/ym7101.v" "$src/baseline_ym7101.v"
        rename_baseline_modules "$BASELINE_DIR/cores/s18/hdl/ym_lib.v" "$src/baseline_ym_lib.v"
        rename_baseline_modules "$BASELINE_DIR/cores/s18/hdl/vram.sv" "$src/baseline_vram.sv"
        write_manifest "$src" "$BUILD_DIR"
    fi
    if ((dry_run)); then
        echo "compile_defines=-D$TEST_MODE -DSIMULATION -DJTFRAME_MCLK=48000000"
        case "$GEOMETRY" in
            384x260) echo "compile_defines+=-DPASSIVE_384_260" ;;
            384x261) echo "compile_defines+=-DPASSIVE_384_261" ;;
        esac
        if ((TRANSITIONS)); then echo "compile_defines+=-DPASSIVE_TRANSITIONS"; fi
        if [[ "$SCENARIO" == service ]]; then echo "compile_defines+=-DSERVICE_SCENARIO"; fi
        if [[ "$SCENARIO" == features ]]; then echo "compile_defines+=-DFEATURES_SCENARIO"; fi
        if [[ "$SCENARIO" == legacy_formats ]]; then echo "compile_defines+=-DLEGACY_FORMATS_TEST"; fi
        if [[ "$SCENARIO" == copy_first ]]; then echo "compile_defines+=-DSERVICE_COPY_FIRST"; fi
        if [[ "$SCENARIO" == copy_read_before ]]; then echo "compile_defines+=-DSERVICE_SCENARIO -DSERVICE_COPY_READ_BEFORE"; fi
        if [[ "$SCENARIO" == irq_hv ]]; then echo "compile_defines+=-DIRQ_HV_SCENARIO"; fi
        if [[ "$SCENARIO" == geometry_switch ]]; then echo "compile_defines+=-DGEOMETRY_SWITCH_SCENARIO"; fi
        if [[ "$SCENARIO" == production_switch ]]; then echo "compile_defines+=-DGEOMETRY_SWITCH_SCENARIO -DPRODUCTION_TIMER_SCENARIO"; fi
        echo "selected_geometry=$GEOMETRY scenario=$SCENARIO transitions=$TRANSITIONS"
        echo "cpu_start_delay96=$CPU_START_DELAY96"
        echo "copy_first_start=$COPY_START"
        echo "candidate_compile_inputs=$src/candidate_ym7101.v,$src/candidate_ym_lib.v,$src/candidate_vram.sv,$src/candidate_ym7101_raster.v,$src/candidate_jts16_vtimer.v"
        echo "frame_timing_compile_input=$src/candidate_jtframe_vtimer.v (SIMULATION define enabled)"
        echo "baseline_compile_inputs=$src/baseline_ym7101.v,$src/baseline_ym_lib.v,$src/baseline_vram.sv"
        echo "bench_compile_input=$src/test.v"
        echo "scenario_include=$src/service_profile.vh,$src/irq_hv_profile.vh,$src/features_profile.vh,$src/legacy_formats.vh"
        echo "documentation_input=$src/README.md"
        return 0
    fi
    build_runner "$src" "$BUILD_DIR/obj_dir"
    cd "$BUILD_DIR"
    set +e
    "$BUILD_DIR/obj_dir/Vtest" "${run_args[@]}"
    status=$?
    set -e
    echo "runner_elapsed_seconds=$((SECONDS-started))"
    return "$status"
}

main "$@"
