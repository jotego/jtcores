#!/bin/bash
set -euo pipefail

main() {
    local core=${1:-}
    local core_define=${core^^}
    local vtotal=${2:-272}
    local video_file
    local video_source
    local tempdir
    local cfgstr
    local name
    local value
    local -a macroargs=()
    local -a dirs=()
    local -a simargs=()
    local -A seen=()

    if [[ -z "$core" ]]; then
        echo "Usage: $0 <blkout|pktgal|sf|sarms|gae1|toki> [gae1-vtotal]" >&2
        return 2
    fi

    video_file=$(video_source "$core") || return 2
    tempdir=$(mktemp -d)
    preserve_generated_files "$tempdir"
    trap "restore_generated_files '$tempdir'; python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' '$tempdir'" EXIT
    jtframe mem "$core"
    jtframe mmr "$core"
    jtframe files sim "$core" --target=mister
    cp game.f "$tempdir/game.f"

    cfgstr=$(jtframe cfgstr "$core" --target=mister --output=bash)
    eval "$cfgstr"
    while IFS= read -r name; do
        value=${!name}
        if [[ -z "$value" ]]; then
            macroargs+=("-D$name")
        else
            macroargs+=("-D$name=$value")
        fi
    done < <(sed -n 's/^export \([^=]*\)=.*/\1/p' <<< "$cfgstr")

    while IFS= read -r name; do
        local dir=${name%/*}
        if [[ -z "${seen[$dir]+x}" ]]; then
            dirs+=("-y" "$dir")
            seen[$dir]=1
        fi
    done < "$tempdir/game.f"

    macroargs+=("-DCORE_$core_define")
    if [[ "$core" == gae1 ]]; then
        macroargs+=("-DTEST_VTOTAL=$vtotal")
    fi
    video_source="$CORES/$core/hdl/$video_file"
    if [[ -n "${SOURCE_REV:-}" ]]; then
        git show "$SOURCE_REV:cores/$core/hdl/$video_file" > "$tempdir/$video_file"
        video_source="$tempdir/$video_file"
        macroargs+=("-DMEASURE_ONLY")
    fi
    iverilog -g2012 -DSIMULATION -Y .sv "${macroargs[@]}" \
        -I "$JTFRAME/hdl/inc" -I "$CORES/$core/mist" \
        "${dirs[@]}" -s test -o "$tempdir/sim" \
        "$video_source" "$(dirname "$0")/test.v" || return 1

    if [[ "${WAVEFORM:-0}" == 1 ]]; then simargs+=(+wave); fi
    ( cd "$tempdir" && vvp ./sim "${simargs[@]}" )
    if [[ "${WAVEFORM:-0}" == 1 ]]; then
        cp "$tempdir/sync_phase.vcd" "$PWD/sync_phase_$core.vcd"
    fi

    if [[ -z "${SOURCE_REV:-}" && "${SKIP_RESYNC:-0}" != 1 ]]; then
        iverilog -g2012 -DSIMULATION -Y .sv "${macroargs[@]}" \
            -I "$JTFRAME/hdl/inc" -I "$CORES/$core/mist" \
            "${dirs[@]}" -s resync_test -o "$tempdir/resync_sim" \
            "$video_source" "$(dirname "$0")/resync_test.v"
        ( cd "$tempdir" && vvp ./resync_sim )
    fi
}

preserve_generated_files() {
    local tempdir=$1
    for name in game.f jtsim_vhdl.f; do
        if [[ -e "$name" ]]; then
            cp "$name" "$tempdir/$name.before"
            touch "$tempdir/$name.existed"
        fi
    done
}

restore_generated_files() {
    local tempdir=$1
    for name in game.f jtsim_vhdl.f; do
        if [[ -e "$tempdir/$name.existed" ]]; then
            cp "$tempdir/$name.before" "$name"
        else
            python3 -c 'from pathlib import Path; Path(__import__("sys").argv[1]).unlink(missing_ok=True)' "$name"
        fi
    done
}

video_source() {
    case "$1" in
        blkout) echo jtblkout_video.v ;;
        pktgal) echo jtpktgal_video.v ;;
        sf) echo jtsf_video.v ;;
        sarms) echo jtsarms_video.v ;;
        gae1) echo jtgae1_video.v ;;
        toki) echo jttoki_video.v ;;
        *) echo "Unknown core: $1" >&2; return 1 ;;
    esac
}

main "$@"
