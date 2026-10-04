#!/bin/bash
# Boot battery: for each set, sim 12 frames with the ARM PC dumper and check the
# MAME per-instruction boot trace is an in-order subsequence of the FPGA fetch
# stream (verify_arm_boot.sh). Also reports distinct frame CRCs (screen alive).
# Sets without a zip (or parent zip) in $ROMS_HOST are skipped.
# Usage: ./boot_check.sh [set ...]   (default: every set with a zip available)
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
JTROOT=$(cd "$HERE/../../.." && pwd)
ROMS_HOST="${ROMS_HOST:-$HOME/.mame/roms-local}"
MAMEBIN="${MAMEBIN:-$HOME/Emus/mame0276-arm64/mame}"
IMAGE=${IMAGE:-jotego/simulator:arm64}
FRAMES=${FRAMES:-12}

ALLSETS=(osman candance joemacr joemacra chainrec magdrop magdropp charlien prtytime gangonta hvysmsh hvysmsha)
parent_of() {
    case "$1" in
        candance) echo osman;;
        joemacra|joemacrj) echo joemacr;;
        magdrop|magdropp) echo chainrec;;
        gangonta) echo prtytime;;
        *) echo "";;
    esac
}

SETS=("$@"); [ ${#SETS[@]} -eq 0 ] && SETS=("${ALLSETS[@]}")

have_zip() { # set zip or parent zip present
    [ -e "$ROMS_HOST/$1.zip" ] && return 0
    local p; p=$(parent_of "$1")
    [ -n "$p" ] && [ -e "$ROMS_HOST/$p.zip" ]
}

mame_trace() { # make ver/<set>/traces/arm_boot.tr if missing
    local set=$1 out="$HERE/$set/traces/arm_boot.tr"
    [ -s "$out" ] && return 0
    [ -x "$MAMEBIN" ] || { echo "no MAME binary"; return 1; }
    local lua=/tmp/osman_bootchk_$set.lua
    cat > $lua <<EOF
local done=false
emu.register_periodic(function()
    if done then return end
    local db = manager.machine.debugger
    if db then
        db:command("trace /tmp/osman_bootchk_$set.tr,maincpu,noloop")
        db:command("go")
        done=true
    end
end)
EOF
    "$MAMEBIN" $set -rompath "$ROMS_HOST" -debug -debugger none -video none -sound none \
        -seconds_to_run 2 -autoboot_script $lua -nothrottle > /dev/null 2>&1
    [ -s /tmp/osman_bootchk_$set.tr ] || return 1
    mkdir -p "$HERE/$set/traces"
    head -1600 /tmp/osman_bootchk_$set.tr > "$out"
}

use_linux_jtframe() { # docker needs the linux-arm64 jtframe binary in place
    local BIN="$JTROOT/modules/jtframe/src/jtframe/jtframe"
    if [ -f "$BIN.linux-arm64" ] && ! cmp -s "$BIN.linux-arm64" "$BIN"; then
        cp -f "$BIN.linux-arm64" "$BIN"
    fi
}

refresh_roms() { # regenerate MRAs + roms once, so jtsim's staleness check passes.
    # Exit code ignored: sets without zips report errors but the available roms build.
    docker run --platform linux/arm64 --rm -v "$JTROOT:/jtcores" \
        -v "$ROMS_HOST:/root/.mame/roms:ro" -w /jtcores --entrypoint bash "$IMAGE" -c "
source modules/jtframe/bin/setprj.sh --quiet
jtframe mra osman --skipPocket
" > /tmp/osman_bootchk_mra.log 2>&1 || true
    rm -f "$HERE/game/sdram_bank"?.bin
}

run_sim() { # 12-frame sim with the PC dumper
    local set=$1
    docker run --platform linux/arm64 --rm -v "$JTROOT:/jtcores" \
        -v "$ROMS_HOST:/root/.mame/roms:ro" -w /jtcores --entrypoint bash "$IMAGE" -c "
unset VERILATOR_ROOT
source modules/jtframe/bin/setprj.sh --quiet
cd cores/osman/ver/game
jtsim -setname $set -video $FRAMES -d OSMAN_PCTRACE
" > /tmp/osman_bootchk_$set.log 2>&1
    grep -q "JTSIM finished" /tmp/osman_bootchk_$set.log
}

use_linux_jtframe
refresh_roms
printf "%-10s %-6s %s\n" "SET" "CRCs" "RESULT"
for set in "${SETS[@]}"; do
    if ! have_zip $set; then
        printf "%-10s %-6s %s\n" $set "-" "SKIP (no zip)"
        continue
    fi
    if ! mame_trace $set; then
        printf "%-10s %-6s %s\n" $set "-" "FAIL (no MAME trace)"
        continue
    fi
    if ! run_sim $set; then
        printf "%-10s %-6s %s\n" $set "-" "FAIL (sim, see /tmp/osman_bootchk_$set.log)"
        continue
    fi
    crcs=$(sort -u "$HERE/game/frames/frames.crc" 2>/dev/null | wc -l | tr -d ' ')
    res=$(bash "$HERE/osman/verify_arm_boot.sh" "$HERE/game/osman_arm_fpga.tr" "$HERE/$set/traces/arm_boot.tr" 2>&1 | tail -1)
    printf "%-10s %-6s %s\n" $set "$crcs" "$res"
done
