#!/usr/bin/env bash
set -euo pipefail

require_marker() {
    local log_file=$1
    local marker=$2
    if ! rg -Fq "$marker" "$log_file"; then
        echo "simulation did not reach PASS marker: $marker" >&2
        exit 1
    fi
}

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$test_dir" rev-parse --show-toplevel)
out_root=${1:-${TMPDIR:-/tmp}/jtframe-ascal-capture-$$}
mkdir -p "$out_root"
source_dir="$out_root/source"
mkdir -p "$source_dir"
cp "$repo_root/modules/jtframe/target/mister/hdl/sys/ascal.vhd" "$source_dir/ascal.vhd"
cp "$test_dir/ascal_avalon_mem_model.vhd" "$source_dir/ascal_avalon_mem_model.vhd"
cp "$test_dir/test.vhd" "$source_dir/test.vhd"
sha256sum "$source_dir/ascal.vhd" "$source_dir/ascal_avalon_mem_model.vhd" \
    "$source_dir/test.vhd" > "$source_dir/SHA256SUMS"

ghdl -a --std=08 --workdir="$out_root" \
    "$source_dir/ascal.vhd" \
    "$source_dir/ascal_avalon_mem_model.vhd" \
    "$source_dir/test.vhd"
ghdl -e --std=08 --workdir="$out_root" test

for fill in 00 A5; do
    for capture in false true; do
        run_dir="$out_root/fill-$fill/capture-$capture"
        mkdir -p "$run_dir"
        ghdl -r --std=08 --workdir="$out_root" test \
            -gCAPTURE_ENABLE="$capture" -gPADDING_FILL="x\"$fill\"" \
            --ieee-asserts=disable --assert-level=error --stop-time=2300us \
            > "$run_dir/sim.log" 2>&1
        cat "$run_dir/sim.log"
        require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'
    done
done

# A short real pipeline run crosses the write-ID wrap point without billions
# of ordinary frames; the scaler under test remains the production entity.
run_dir="$out_root/write-id-wrap"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gSEED_WRITE_IDS_NEAR_WRAP=true -gCOALESCE_TWO_ACKS=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/rejected-pre-ready-release"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gRELEASE_BEFORE_READY=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS rejected pre-READY RELEASE ACK and matching cleanup'

run_dir="$out_root/final-beat-stall"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gSTALL_CAPTURE_FINAL=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'
require_marker "$run_dir/sim.log" 'capture producer quiet; target requests=00013 expected=00013'
require_marker "$run_dir/sim.log" 'capture Avalon drain complete; final ID='
require_marker "$run_dir/sim.log" 'PASS explicit returned-read coverage: bursts=18 beats=288'

run_dir="$out_root/staging-collision-half0"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gSEED_WRITE_IDS_NEAR_WRAP=true -gEXPECT_WRITE_COLLISION=true \
    -gCOLLISION_STALL_HALF0=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS capture staging collision failed closed with WRITE_OVERRUN'
if ! rg -q 'capture WRITE_OVERRUN half=0' "$run_dir/sim.log"; then
    echo "staging collision test did not exercise half 0" >&2
    exit 1
fi

run_dir="$out_root/staging-collision-half1"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gSEED_WRITE_IDS_NEAR_WRAP=true -gEXPECT_WRITE_COLLISION=true \
    -gCOLLISION_STALL_HALF1=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS capture staging collision failed closed with WRITE_OVERRUN'
if ! rg -q 'capture WRITE_OVERRUN half=1' "$run_dir/sim.log"; then
    echo "staging collision test did not exercise half 1" >&2
    exit 1
fi

run_dir="$out_root/idle-progressive"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gARM_CAPTURE=false -gTEST_IDLE_PROGRESS=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/idle-interlaced"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=false -gARM_CAPTURE=false -gINTERLACED_SOURCE=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS wrapper-disabled capture interlaced video remains unstopped'

run_dir="$out_root/unsupported-arm"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gUNSUPPORTED_MODE_ARM=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS unsupported ARM rejected without stopping ordinary video'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/armed-fault-watchdog"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gARMED_FAULT_WATCHDOG=true -gCAPTURE_HOLD_MS=100 \
    -gWATCHDOG_CYCLES_PER_MS=10 -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS ARMED fault watchdog released hold and preserved sticky fault'

run_dir="$out_root/lifecycle-producer-error"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gLIFECYCLE_ERROR_BEFORE_ARM=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS ARM rejected unknown or errored lifecycle state'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/lifecycle-unknown"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gLIFECYCLE_UNKNOWN_BEFORE_ARM=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS ARM rejected unknown or errored lifecycle state'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/lifecycle-clean-idle-no-arm"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=1 -gCLEAN_IDLE_ONLY=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS observed clean IDLE permits recovery drain but blocks CAP ARM'

run_dir="$out_root/lifecycle-stop-before-target"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gLIFECYCLE_STOP_BEFORE_TARGET=true \
    -gCAPTURE_HOLD_MS=100 -gWATCHDOG_CYCLES_PER_MS=100 -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS pre-target lifecycle STOP automatically drained and released ownership'
require_marker "$run_dir/sim.log" 'capture lifecycle cancellation coincident with native EOF'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/bad-release-watchdog-priority"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gBAD_RELEASE_THEN_ABORT=true \
    -gWATCHDOG_AFTER_BAD_RELEASE=true -gCAPTURE_HOLD_MS=100 -gWATCHDOG_CYCLES_PER_MS=100 \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS later watchdog kept the first BAD_RELEASE diagnostic'
require_marker "$run_dir/sim.log" 'PASS wrong release retained ownership; matching abort cleaned up'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/watchdog-rearm"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gEXPECT_WATCHDOG=true -gHALT_INPUT_CLOCK_ON_READY=true -gREARM_AFTER_CLEANUP=true \
    -gCAPTURE_HOLD_MS=100 -gWATCHDOG_CYCLES_PER_MS=100 \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS watchdog cleanup and fault-clear re-arm'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/watchdog-rejected-abort"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gEXPECT_WATCHDOG=true -gCAPTURE_HOLD_MS=100 -gWATCHDOG_CYCLES_PER_MS=100 \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS bounded watchdog cleanup and rejected post-watchdog ABORT ACK'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/two-result-rearm"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gDOUBLE_CAPTURE_SUCCESS=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS two fresh READY results with delayed cache ACK and clean re-arm'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/ready-result-reset"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 -gRESET_READY_RESULT=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS shared reset invalidated held descriptor and result mailbox'

run_dir="$out_root/unexpected-armed-live-result"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_UNEXPECTED_REARM=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS unexpected ARMED canceled active owner and preserved its result'

run_dir="$out_root/unknown-lifecycle-active-owner"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_UNKNOWN_ACTIVE_REARM=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS unknown lifecycle state canceled active owner and preserved its result'

run_dir="$out_root/lifecycle-arm-race"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_REARM_RACE=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS same-edge invalid ARMED and CAP ARM rejected with old READY ownership drained'

run_dir="$out_root/lifecycle-armed-running-race"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_START_ARM_RACE=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS same-edge ARMED-to-RUNNING progress allowed CAP ARM'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/lifecycle-running-done-arm-race"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_DONE_ARM_RACE=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS same-edge RUNNING-to-DONE progress allowed CAP ARM'

for beat in {0..15}; do
    run_dir="$out_root/fence-corrupt-$beat"
    mkdir -p "$run_dir"
    ghdl -r --std=08 --workdir="$out_root" test \
        -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gFENCE_CORRUPTION_TEST=true \
        -gFENCE_CORRUPT_BEAT="$beat" -gPADDING_FILL='x"00"' \
        --ieee-asserts=disable --assert-level=error --stop-time=2300us \
        > "$run_dir/sim.log" 2>&1
    cat "$run_dir/sim.log"
    require_marker "$run_dir/sim.log" "injected exact-header fence corruption at beat $beat"
    require_marker "$run_dir/sim.log" 'PASS exact header fence corruption was rejected and drained'
done

# Prove the corruption test fails when the injection is disabled.
run_dir="$out_root/fence-corruption-disabled-probe"
mkdir -p "$run_dir"
if ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gFENCE_CORRUPTION_TEST=true -gFENCE_CORRUPT_BEAT=16 \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1; then
    echo "disabled fence injection unexpectedly passed its corruption test" >&2
    exit 1
fi
if ! rg -Fq 'fence corruption did not fault, drain all beats, and clean up' "$run_dir/sim.log"; then
    cat "$run_dir/sim.log"
    echo "disabled fence injection failed for an unrelated reason" >&2
    exit 1
fi

run_dir="$out_root/wide-scan-address"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=1 -gLARGE_SCAN_TEST=true \
    -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=30000us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS 1200-burst large scan boundary 511/512/1199, CRC, RGB, fence, release'

run_dir="$out_root/cached-running-before-arm"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_RUNNING_BEFORE_ARM=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2300us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS cached RUNNING lifecycle consumed on ARM'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'

run_dir="$out_root/cached-armed-clean-start"
mkdir -p "$run_dir"
ghdl -r --std=08 --workdir="$out_root" test \
    -gCAPTURE_ENABLE=true -gCAPTURE_ARM_CHECKPOINT=10 \
    -gLIFECYCLE_ARMED_REARM=true -gPADDING_FILL='x"00"' \
    --ieee-asserts=disable --assert-level=error --stop-time=2600us \
    > "$run_dir/sim.log" 2>&1
cat "$run_dir/sim.log"
require_marker "$run_dir/sim.log" 'PASS clean ARMED lifecycle starts after prior result cleanup'
require_marker "$run_dir/sim.log" 'PASS actual ascal input/Avalon model'
