#!/bin/bash
set -euo pipefail

main() {
    init_globals
    parse_args "$@"
    validate_args
    setup_environment
    configure_parallelism
    acquire_lock
    install_lock_release_trap
    run_requested_tests
}

    init_globals() {
    ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
    JTROOT_DEFAULT="$(cd "$ROOT_DIR/../../../.." && pwd)"
    cd "$ROOT_DIR"

    implemented_tests=(
        T00_CPUMap_RangeCoverage
        T01_CPUMap_BiosSimmWindows
        T02_BIOS_vs_OPCODE_Map
        T03_SecurityDecryption_AltModes
        T04_sh2cache_DecryptedAlias
        T05_IOStatus_ReadSmoke
        T06_SpriteDMA_TriggerAndClear
        T07_CharacterDMA_CommandList
        T08_CharacterRAM_BankedWindow
        T09_PaletteDMA_Engine
        T10_GFXFlash_BankAndIO
        T11_ProgramFlashSIMM_DecodeAndWrite
        T12_WorkRAM_CopyScan
        T13_SpriteRAM_Smoke
        T14_SSRAM_Readback
        T15_PaletteRAM_Smoke
        T16_CharRAM_Smoke
        T17_SSram_UMask
        T18_SSRegs_WriteOnlyFields
        T19_PPUWriteOnlyRegisterLatching
        T20_WD33C93_Path
        T21_NoOpAndUnknownRegions
        T22_SH2DMA_DecryptionBypass
        T23_ResetVisibleState
        T24_RegisterByteLaneAndMaskSemantics
        T25_SCSI_CDROM_MinimalCommand
        T26_SH2DMAC_EnableGateAndAbort
        T27_SIMMFlashAutoselectID
        T28_SH2DMA_SIMMFlashAutoselectID
        T29_SH2DMA_SIMMFlashCommandWrites
        T30_SIMMFlashCPUProtocolExtras
        T31_SH2DMA_BIOSFlashCommandSource
        T32_SIMMFlashMissingAndLanes
        T33_GFXFlashLanesAndAbsentBanks
        T35_CharacterDMA_DataCommands
        T38_CharacterDMA_TableAndRLE
        T39_CharacterDMA_DestinationWrap
        T40_SIMM2FlashAutoselectID
        T41_SH7604_InstSplitReplay
        T42_SH7604_StallSaveReplay
        T43_SH7604_DatBufAlignment
        T44_CharacterDMA_EndMarkerStatus
        T45_CPUMap_BoundaryEdges
        T46_GFXFlash_DataInterleave
        T48_SH7604_MultiplierMAC
        T49_SH7604_StaticBranchSplit
        T50_SH7604_SaveIdReplay
        T51_SH7604_DIVUOverflowIRQ
        T36_EEPROMAndWD33C93_Probes
    )

    rom_key_tests=(
        T37_ROMBaselineCAPSignature
        T52_ROMBaselineSIMM2Signature
        T53_ROMBaselineJojobanSIMM2Signature
    )

    test_name=""
    run_all=0
    keep=0
    lock_held=0
    parallel_jobs="${CPS3_CPU_TEST_JOBS:-}"
    setname="${CPS3_CPU_TEST_SETNAME:-sfiiin}"
    jtsim_args=()
    runtime_base_args=()
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --test)
                test_name="${2:-}"
                shift 2
                ;;
            --all)
                run_all=1
                shift
                ;;
            --keep)
                keep=1
                shift
                ;;
            --setname)
                setname="${2:-}"
                shift 2
                ;;
            --jobs)
                parallel_jobs="${2:-}"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                jtsim_args+=("$1")
                shift
                ;;
        esac
    done
}

usage() {
    cat <<'USAGE'
Usage: ./sim.sh --test <test-name> [--keep] [jtsim args...]
       ./sim.sh --all [--jobs <n>] [--keep] [jtsim args...]

Options:
  --test <name> Run asm/tests/<name>.s.
  --all         Run the implemented CPU tests in parallel.
  --jobs <n>    Limit --all to <n> concurrent simulations
                (default: CPS3_CPU_TEST_JOBS or host CPU count).
  --keep        Keep waveforms and generated per-test artifacts.
  --setname <n> Use $JTROOT/rom/<n>.rom for jtutil baseline generation.
  -h, --help    Show this help.
USAGE
}

validate_args() {
    if [ "$run_all" -eq 0 ] && [ -z "$test_name" ]; then
        echo "ERROR: use --test <name> or --all" >&2
        usage >&2
        exit 1
    fi

    if [ "$run_all" -eq 1 ] && [ -n "$test_name" ]; then
        echo "ERROR: --test and --all are mutually exclusive" >&2
        exit 1
    fi

    if [ -n "$parallel_jobs" ] && ! [[ "$parallel_jobs" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --jobs expects a positive integer" >&2
        exit 1
    fi

    if [ -n "$parallel_jobs" ] && [ "$parallel_jobs" -lt 1 ]; then
        echo "ERROR: --jobs expects a positive integer" >&2
        exit 1
    fi
}

setup_environment() {
    if [ -z "${JTROOT:-}" ] || [ ! -d "${JTROOT:-}/cores/cps3" ]; then
        pushd "$JTROOT_DEFAULT" >/dev/null
        # shellcheck disable=SC1091
        source ./setprj.sh >/dev/null
        popd >/dev/null
    fi

    if ! command -v jtsim >/dev/null 2>&1; then
        echo "ERROR: jtsim not found; source setprj.sh first" >&2
        exit 1
    fi
}

configure_parallelism() {
    if [ -z "$parallel_jobs" ]; then
        if command -v nproc >/dev/null 2>&1; then
            parallel_jobs="$(nproc)"
        else
            parallel_jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
        fi
    fi

    if [ -z "$parallel_jobs" ] || [ "$parallel_jobs" -lt 1 ]; then
        parallel_jobs=1
    fi

    build_runtime_base_args
}

build_runtime_base_args() {
    local i=0

    runtime_base_args=(-time 200)
    while [ "$i" -lt "${#jtsim_args[@]}" ]; do
        case "${jtsim_args[$i]}" in
            -time|-frame)
                runtime_base_args+=("${jtsim_args[$i]}")
                i=$((i + 1))
                if [ "$i" -lt "${#jtsim_args[@]}" ]; then
                    runtime_base_args+=("${jtsim_args[$i]}")
                fi
                ;;
            --trace|+*)
                runtime_base_args+=("${jtsim_args[$i]}")
                ;;
        esac
        i=$((i + 1))
    done

    if [ "$keep" -eq 1 ]; then
        runtime_base_args+=(--trace)
    fi
}

acquire_lock() {
    if command -v flock >/dev/null 2>&1; then
        exec 9>.cputest.lock
        flock 9
        lock_held=1
    fi
}

install_lock_release_trap() {
    trap release_lock EXIT
}

release_lock() {
    if [ "${lock_held:-0}" -eq 1 ]; then
        flock -u 9 || true
        exec 9>&-
        lock_held=0
    fi
}

run_requested_tests() {
    prepare_shared_sim_build

    if [ "$run_all" -eq 1 ]; then
        run_all_parallel
    else
        run_one "$test_name"
    fi
}

prepare_shared_sim_build() {
    local build_dir="work/shared_build"
    local log_path="$build_dir/jtsim-build.log"
    local sim_args=(
        -mr
        -u JTFRAME_SDRAM_LARGE
        -d CPS3_CPU_TEST
        -d VERILATOR_KEEP_CPU
        -d JTFRAME_SIM_SKIP_VSIZE
        -d CPS3_CPU_TEST_SPRDMA_OBSERVER
        -dipsw 0
        -time 0
    )
    local extra_args=()
    local i=0
    local rc

    mkdir -p "$build_dir"
    rm -f rom.bin test.fst test.vcd
    truncate -s 32 rom.bin

    if [ "$keep" -eq 1 ]; then
        sim_args+=(-w)
    fi

    while [ "$i" -lt "${#jtsim_args[@]}" ]; do
        case "${jtsim_args[$i]}" in
            -time|-frame)
                i=$((i + 2))
                ;;
            +*)
                i=$((i + 1))
                ;;
            *)
                extra_args+=("${jtsim_args[$i]}")
                i=$((i + 1))
                ;;
        esac
    done

    echo "Building shared cputest simulator"
    set +e
    jtsim "${sim_args[@]}" "${extra_args[@]}" >"$log_path" 2>&1
    rc=$?
    set -e

    if [ "$rc" -ne 0 ] || [ ! -x obj_dir/sim ]; then
        tail -80 "$log_path" >&2 || true
        echo "ERROR: shared cputest simulator build failed; see ${log_path}" >&2
        return 1
    fi
}

run_all_parallel() {
    local name
    local rc
    local failures=0
    local skipped=0
    local passed
    local total="${#implemented_tests[@]}"
    local prepared_tests=()

    for name in "${implemented_tests[@]}"; do
        set +e
        prepare_one "$name"
        rc=$?
        set -e
        case "$rc" in
            0) prepared_tests+=("$name") ;;
            2) skipped=$((skipped + 1)) ;;
            *) return "$rc" ;;
        esac
    done

    echo "Running ${#prepared_tests[@]} tests with ${parallel_jobs} jobs"
    for name in "${prepared_tests[@]}"; do
        wait_for_parallel_slot
        run_prepared "$name" &
    done

    while [ "$(active_parallel_jobs)" -gt 0 ]; do
        if ! wait -n; then
            failures=$((failures + 1))
        fi
    done

    passed=$((${#prepared_tests[@]} - failures))
    if [ "$failures" -ne 0 ]; then
        echo "ERROR: ${failures} cputest(s) failed" >&2
        echo "SUMMARY: FAIL total=${total} passed=${passed} failed=${failures} skipped=${skipped}" >&2
        return 1
    fi

    echo "SUMMARY: PASS total=${total} passed=${passed} failed=0 skipped=${skipped}"
}

wait_for_parallel_slot() {
    while [ "$(active_parallel_jobs)" -ge "$parallel_jobs" ]; do
        if ! wait -n; then
            failures=$((failures + 1))
        fi
    done
}

active_parallel_jobs() {
    jobs -pr | wc -l | tr -d ' '
}

run_one() {
    local name="$1"

    prepare_one "$name"
    run_prepared "$name"
}

prepare_one() {
    local name="$1"
    local work_dir="work/${name}"
    local require_rom_keys=0
    local rom_path="$JTROOT/rom/${setname}.rom"
    local test_bin

    if test_uses_rom_keys "$name"; then
        require_rom_keys=1
        if [ ! -f "$rom_path" ]; then
            if [ "$run_all" -eq 1 ]; then
                echo "SKIP ${name}: $rom_path not found; ROM keys/baseline required"
                return 2
            fi
            echo "ERROR: ${name} requires $rom_path for ROM keys/baseline" >&2
            return 1
        fi
    fi

    rm -rf "$work_dir"
    mkdir -p "$work_dir"

    make_baseline "$work_dir" "$require_rom_keys" "$name"
    test_bin="$(./build.sh --test "$name")"
    dd if="$test_bin" of="$work_dir/sdram_bank0.bin" bs=1 conv=notrunc status=none
    seed_test_fixture "$name" "$work_dir"
    link_runtime_banks "$work_dir"
}

run_prepared() {
    local name="$1"
    local work_dir="work/${name}"
    local run_dir="$work_dir/run"
    local log_path="$work_dir/jtsim.log"
    local sim_exe="$ROOT_DIR/obj_dir/sim"
    local rc
    local args=("${runtime_base_args[@]}")

    if test_uses_rom_keys "$name"; then
        local cps3_key1
        local cps3_key2
        cps3_key1="$(read_rom_key_hex "$JTROOT/rom/${setname}.rom" 16)"
        cps3_key2="$(read_rom_key_hex "$JTROOT/rom/${setname}.rom" 20)"
        echo "Using ROM keys for ${name}: cps3_key1=0x${cps3_key1} cps3_key2=0x${cps3_key2}"
        args+=("+cps3_key1=${cps3_key1}")
        args+=("+cps3_key2=${cps3_key2}")
    fi

    rm -f "$run_dir/test.fst" "$run_dir/test.vcd"

    echo "Running ${name}"
    set +e
    (
        cd "$run_dir" || exit 1
        "$sim_exe" "${args[@]}"
    ) >"$log_path" 2>&1
    rc=$?
    set -e

    convert_kept_waveform "$run_dir" "$log_path"
    report_result "$name" "$log_path" "$rc"
}

test_uses_rom_keys() {
    local name="$1"
    local key_test

    for key_test in "${rom_key_tests[@]}"; do
        [ "$name" = "$key_test" ] && return 0
    done
    return 1
}

read_rom_key_hex() {
    local rom_path="$1"
    local offset="$2"
    local hex

    hex="$(od -An -N4 -tx1 -v -j "$offset" "$rom_path" \
        | tr -d ' \n' \
        | tr '[:lower:]' '[:upper:]')"
    if [ "${#hex}" -ne 8 ]; then
        echo "ERROR: could not read 32-bit key at offset ${offset} from ${rom_path}" >&2
        return 1
    fi
    printf '%s\n' "$hex"
}

make_baseline() {
    local dst="$1"
    local require_rom_baseline="${2:-0}"
    local name="${3:-test}"
    mkdir -p "$dst"

    if [ -f "$JTROOT/rom/${setname}.rom" ]; then
        local baseline_dir="work/baseline_${setname}"
        mkdir -p "$baseline_dir"
        if [ "$require_rom_baseline" -eq 1 ]; then
            rm -f "$baseline_dir"/sdram_bank*.bin
        fi
        if ! have_baseline "$baseline_dir"; then
            if ! generate_jtutil_baseline "$baseline_dir"; then
                if [ "$require_rom_baseline" -eq 1 ]; then
                    echo "ERROR: jtutil baseline generation failed for ${setname}; ${name} requires ROM baseline" >&2
                    return 1
                fi
                echo "WARN: jtutil baseline generation failed for ${setname}; using zero-filled SDRAM baseline" >&2
                make_zero_banks "$baseline_dir"
            fi
        fi
        copy_or_zero_banks "$baseline_dir" "$dst" sdram_bank
        copy_or_zero_banks "$baseline_dir" "$dst" sdram2_bank
    else
        if [ "$require_rom_baseline" -eq 1 ]; then
            echo "ERROR: $JTROOT/rom/${setname}.rom not found; ${name} requires ROM baseline" >&2
            return 1
        fi
        echo "WARN: $JTROOT/rom/${setname}.rom not found; using zero-filled SDRAM baseline" >&2
        make_zero_banks "$dst"
    fi
}

have_baseline() {
    local src="$1"
    local bank

    for bank in 0 1 2 3; do
        [ -s "$src/sdram_bank${bank}.bin" ] || return 1
        [ -s "$src/sdram2_bank${bank}.bin" ] || return 1
    done
    return 0
}

generate_jtutil_baseline() {
    local dst="$1"
    local game_dir="$ROOT_DIR/../game"
    local bank

    (
        cd "$game_dir"
        rm -f sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin sdram2_bank0.bin sdram2_bank1.bin sdram2_bank2.bin sdram2_bank3.bin
        if ! jtutil sdram --target mister -u JTFRAME_SDRAM_LARGE "$setname" --sim; then
            echo "WARN: jtutil --sim baseline generation failed for ${setname}; retrying without --sim" >&2
            rm -f sdram_bank0.bin sdram_bank1.bin sdram_bank2.bin sdram_bank3.bin sdram2_bank0.bin sdram2_bank1.bin sdram2_bank2.bin sdram2_bank3.bin
            jtutil sdram --target mister -u JTFRAME_SDRAM_LARGE "$setname"
        fi
    ) || return 1

    copy_or_zero_banks "$game_dir" "$dst" sdram_bank
    copy_or_zero_banks "$game_dir" "$dst" sdram2_bank
}

make_zero_banks() {
    local dst="$1"
    mkdir -p "$dst"
    for bank in 0 1 2 3; do
        truncate -s 16777216 "$dst/sdram_bank${bank}.bin"
        truncate -s 16777216 "$dst/sdram2_bank${bank}.bin"
    done
}

copy_or_zero_banks() {
    local src="$1"
    local dst="$2"
    local prefix="$3"
    local bank

    for bank in 0 1 2 3; do
        if [ -s "$src/${prefix}${bank}.bin" ]; then
            cp "$src/${prefix}${bank}.bin" "$dst/${prefix}${bank}.bin"
        else
            truncate -s 16777216 "$dst/${prefix}${bank}.bin"
        fi
    done
}

seed_test_fixture() {
    local name="$1"
    local dst="$2"

    case "$name" in
        T40_SIMM2FlashAutoselectID)
            seed_simm2_flash_fixture "$dst"
            ;;
        T45_CPUMap_BoundaryEdges)
            seed_simm2_boundary_fixture "$dst"
            ;;
        T07_CharacterDMA_CommandList|\
        T35_CharacterDMA_DataCommands|\
        T38_CharacterDMA_TableAndRLE|\
        T39_CharacterDMA_DestinationWrap)
            seed_chardma_user5_fixture "$dst"
            ;;
        T34_PaletteDMA_DeterministicCopy)
            seed_paldma_user5_fixture "$dst"
            ;;
        T46_GFXFlash_DataInterleave)
            seed_gfxflash_user5_fixture "$dst"
            ;;
    esac
}

seed_simm2_flash_fixture() {
    local dst="$1"
    local bank0="$dst/sdram2_bank0.bin"

    # CPU address 0x06802000 maps to SIMM2 byte offset 0x2000.
    printf '\x40\x22\x5a\xa5' \
        | dd of="$bank0" bs=1 seek=$((0x2000)) conv=notrunc status=none
}

seed_simm2_boundary_fixture() {
    local dst="$1"
    local bank0="$dst/sdram2_bank0.bin"

    printf '\x45\x22\x00\x45' \
        | dd of="$bank0" bs=1 seek=$((0x000000)) conv=notrunc status=none
    printf '\x45\x22\xff\x45' \
        | dd of="$bank0" bs=1 seek=$((0x7ffffc)) conv=notrunc status=none
}

seed_paldma_user5_fixture() {
    local dst="$1"
    local bank1="$dst/sdram_bank1.bin"

    # Palette DMA source 0x00400000 maps to the first user5/gfx cache line.
    # The RTL toggles the source halfword address bit, so the first DMA word
    # comes from byte offset 2 in the full-range bank-1 backing file.
    printf '\x00\x00\x42\x10' \
        | dd of="$bank1" bs=1 seek=$((0x0000)) conv=notrunc status=none
}

seed_chardma_user5_fixture() {
    local dst="$1"
    local bank1="$dst/sdram_bank1.bin"

    # user5 byte 0x0000: command-0 copy fixture for T35.
    printf '\x10\x11\x12\x13\x14\x15\x16\x17' \
        | dd of="$bank1" bs=1 seek=$((0x0000)) conv=notrunc status=none

    # user5 byte 0x0200: decompression table entries.
    # index 1 -> 0x05, 0x43; index 2 -> 0x11, 0x11.
    printf '\x00\x00\x05\x43\x11\x11' \
        | dd of="$bank1" bs=1 seek=$((0x0200)) conv=notrunc status=none

    # user5 byte 0x0400: cmd2 stream, first byte selects table index 1.
    printf '\x81\x06\x07\x08' \
        | dd of="$bank1" bs=1 seek=$((0x0400)) conv=notrunc status=none

    # user5 byte 0x0500: cmd3 stream, first ctrl bit selects table index 2.
    printf '\x80\x82\x02\x22\x33\x44\x55\x66\x77' \
        | dd of="$bank1" bs=1 seek=$((0x0500)) conv=notrunc status=none

    # user5 byte 0x0600: destination-wrap command-0 fixture for T39.
    printf '\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef' \
        | dd of="$bank1" bs=1 seek=$((0x0600)) conv=notrunc status=none

    # user5 byte 0x0700: poison source after the end marker in T38.
    printf '\xcc\xdd\xee\xff\x99\x88\x77\x66' \
        | dd of="$bank1" bs=1 seek=$((0x0700)) conv=notrunc status=none
}

seed_gfxflash_user5_fixture() {
    local dst="$1"
    local bank1="$dst/sdram_bank1.bin"

    # user5 byte 0x000000: bank 2 normal-data read fixture for T46.
    printf '\x10\x21\x32\x43\x54\x65\x76\x87' \
        | dd of="$bank1" bs=1 seek=$((0x000000)) conv=notrunc status=none

    # user5 byte 0x200000: bank 3 normal-data read fixture for T46.
    printf '\x89\x9a\xab\xbc\xcd\xde\xef\xf1' \
        | dd of="$bank1" bs=1 seek=$((0x200000)) conv=notrunc status=none

    # user5 byte 0x400000: bank 4 normal-data read fixture for T46.
    printf '\x24\x35\x46\x57' \
        | dd of="$bank1" bs=1 seek=$((0x400000)) conv=notrunc status=none
}

link_runtime_banks() {
    local dst="$1"
    local run_dir="$dst/run"

    mkdir -p "$run_dir/frames"
    for bank in 0 1 2 3; do
        ln -sfn "../sdram_bank${bank}.bin" "$run_dir/sdram_bank${bank}.bin"
        ln -sfn "../sdram2_bank${bank}.bin" "$run_dir/sdram2_bank${bank}.bin"
    done
    rm -f "$run_dir/rom.bin"
    truncate -s 32 "$run_dir/rom.bin"
}

convert_kept_waveform() {
    local run_dir="$1"
    local log_path="$2"

    if [ "$keep" -ne 1 ] || [ ! -f "$run_dir/test.vcd" ]; then
        return 0
    fi

    if command -v vcd2fst >/dev/null 2>&1; then
        (
            cd "$run_dir" || exit 1
            vcd2fst test.vcd test.fst && rm -f test.vcd
        ) >>"$log_path" 2>&1 || true
    fi
}

report_result() {
    local name="$1"
    local log_path="$2"
    local rc="$3"

    if grep -q "PASS test=" "$log_path"; then
        grep "PASS test=" "$log_path" | tail -1
        return 0
    fi

    if grep -q "FAIL test=" "$log_path"; then
        grep "FAIL test=" "$log_path" | tail -1 >&2
        return 1
    fi

    if [ "$keep" -eq 1 ] && grep -q "VerilatedVcd::addInitCb" "$log_path"; then
        echo "ERROR: ${name} waveform build failed due to a Verilator trace API mismatch" >&2
        echo "       See ${log_path}" >&2
        return 1
    fi

    tail -40 "$log_path" >&2
    echo "ERROR: ${name} ended without PASS/FAIL (jtsim rc=${rc})" >&2
    return 1
}

main "$@"
