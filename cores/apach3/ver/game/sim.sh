#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 29-10-2026

set -euo pipefail
apach3_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
apach3_detach=0
if [ "${1:-}" = --detach ]; then apach3_detach=1; shift; fi
apach3_set=apache3
if [ "${1:-}" = --set ]; then apach3_set=${2:?missing set}; shift 2; fi
case "$apach3_set" in apache3|apache3a|apache3b) ;; *) echo "Unknown Apache 3 set: $apach3_set" >&2; exit 1 ;; esac
apach3_scene=
if [ "${1:-}" = --scene ]; then
    apach3_scene=${2:?missing scene number}; shift 2
    [[ "$apach3_scene" =~ ^[0-9]+$ ]] || { echo 'Invalid scene number' >&2; exit 1; }
    [ -f "$apach3_repo/cores/apach3/ver/$apach3_set/scenes/$apach3_scene/dump.bin" ] || { echo 'Scene not found' >&2; exit 1; }
    set -- -d SIMSCENE -video 4 -time 1000 "$@"
fi
if [ "$apach3_detach" = 1 ] && [ -n "$apach3_scene" ]; then
    echo 'Detached mode supports boot simulations only' >&2
    exit 1
fi
if [ "$#" -eq 0 ]; then set -- -video 600 -time 12000; fi
apach3_dir="$apach3_repo/cores/apach3/ver/$apach3_set"
apach3_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
[ -f "$apach3_repo/rom/$apach3_set.rom" ] || { echo "Generate $apach3_set.rom first" >&2; exit 1; }
apach3_ram=$(printf '%s' "$apach3_set" | tr '[:lower:]' '[:upper:]').RAM
[ -f "$apach3_repo/rom/$apach3_ram" ] || { echo "Generate $apach3_ram first" >&2; exit 1; }
mkdir -p "$apach3_dir/bin" "$apach3_dir/frames" "$apach3_dir/reports"
docker image inspect "$apach3_image" >/dev/null
apach3_docker_options=(--rm)
apach3_output="$apach3_dir/sim.log"
if [ "$apach3_detach" = 1 ]; then
    apach3_docker_options=(-d --name "apach3-$apach3_set-boot")
    apach3_output="$apach3_dir/reports/boot-launch.log"
    rm -f "$apach3_dir/reports/boot.exit"
fi
printf 'Simulation log: %s\n' "$apach3_dir/sim.log"
docker run "${apach3_docker_options[@]}" --pull=never --entrypoint /bin/bash \
    -e APACH3_SCENE_NUMBER="$apach3_scene" \
    -e APACH3_DETACHED="$apach3_detach" \
    -v "$apach3_repo:/jtcores" -v "$apach3_repo/modules:/jtcores/modules:ro" \
    -w "/jtcores/cores/apach3/ver/$apach3_set" \
    "$apach3_image" -lc '
        set -euo pipefail
        if [ "$APACH3_DETACHED" = 1 ]; then
            exec > sim.log 2>&1
            trap '\''printf "%s\n" "$?" > reports/boot.exit'\'' EXIT
        fi
        export JTROOT=/jtcores JTFRAME=/jtcores/modules/jtframe
        export CORES=$JTROOT/cores MODULES=$JTROOT/modules JTBIN=$JTROOT/release
        export ROM=$JTROOT/rom RLS=$JTROOT/release MRA=$JTROOT/release/mra
        export POCKET=$JTFRAME/target/pocket
        apach3_set=$1; shift
        apach3_dir=$CORES/apach3/ver/$apach3_set
        export APACH3_VERILATOR=$(command -v verilator)
        export PATH=$apach3_dir/bin:$JTFRAME/bin:$PATH
        export JTFRAME_REGRESSION=1 MAKEJOBS=-j4
        unset VERILATOR_ROOT
        go build -C "$JTFRAME/src/jtframe" -o "$apach3_dir/bin/jtframe" .
        go build -C "$JTFRAME/src/jtutil" -o "$apach3_dir/bin/jtutil" .
        cat > "$apach3_dir/bin/verilator" <<WRAPPER
#!/bin/bash
exec "\$APACH3_VERILATOR" --timing -I"\$JTFRAME/hdl/cpu/nuv30" "\$@"
WRAPPER
        chmod +x "$apach3_dir/bin/verilator"
        ln -sfn "$ROM/$apach3_set.rom" rom.bin
        ln -sfn "$ROM/${apach3_set^^}.RAM" nvram.bin
        ln -sfn "$JTFRAME/hdl/cpu/nuv30/ucrom.hex" ucrom.hex
        ln -sfn "$JTFRAME/hdl/cpu/nuv30/ucdecode.hex" ucdecode.hex
        apach3_load=(-load)
        if [ -n "$APACH3_SCENE_NUMBER" ]; then
            export APACH3_SCENE="scenes/$APACH3_SCENE_NUMBER"
            apach3_load=()
        fi
        jtsim -verilator -setname "$apach3_set" -skipROM -mister "${apach3_load[@]}" -batch -fast -fx68k "$@"
    ' apach3-sim "$apach3_set" "$@" > "$apach3_output" 2>&1

if [ "$apach3_detach" = 1 ]; then
    printf 'Detached container: apach3-%s-boot\n' "$apach3_set"
    exit 0
fi

if [ -n "$apach3_scene" ]; then
    mkdir -p "$apach3_dir/sim_results"
    apach3_last=$(find "$apach3_dir/frames" -name 'frame_*.png' -print | sort | tail -1)
    [ -n "$apach3_last" ] || { echo 'No scene frame produced' >&2; exit 1; }
    cp "$apach3_last" "$apach3_dir/sim_results/$apach3_scene.png"
    cp "$apach3_dir/sim.log" "$apach3_dir/sim_results/$apach3_scene.log"
fi
