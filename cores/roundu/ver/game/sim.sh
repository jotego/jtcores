#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

set -euo pipefail
roundu_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
roundu_set="$roundu_repo/cores/roundu/ver/roundup5"
roundu_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
roundu_boot=${ROUNDU_BOOT:-boot}
roundu_preload=0
if [ "${1:-}" = --preload ]; then roundu_preload=1; shift; fi
if [ "$#" -eq 0 ]; then set -- -video 650 -time 13000; fi
roundu_args=("$@")
roundu_lint=0
roundu_video=0
for roundu_arg in "$@"; do
    case "$roundu_arg" in -lint) roundu_lint=1 ;; -video|*.cab) roundu_video=1 ;; esac
done
for roundu_i in "${!roundu_args[@]}"; do
    case "${roundu_args[$roundu_i]}" in
        *.cab)
            roundu_cab=${roundu_args[$roundu_i]}
            if [ ! -f "$roundu_cab" ]; then roundu_cab="$roundu_repo/cores/roundu/ver/game/$roundu_cab"; fi
            roundu_cab=$(cd -- "$(dirname -- "$roundu_cab")" && pwd -P)/$(basename -- "$roundu_cab")
            [ -f "$roundu_cab" ] && [[ "$roundu_cab" = "$roundu_repo/"* ]]
            roundu_args[$roundu_i]="/jtcores/${roundu_cab#"$roundu_repo/"}"
            ;;
    esac
done
[ -f "$roundu_repo/rom/roundup5.rom" ] || { echo 'Build roundup5.rom with JTFRAME MRA first.' >&2; exit 1; }
[ "$(wc -c < "$roundu_repo/rom/roundup5.rom" | tr -d ' ')" = 2949120 ]
mkdir -p "$roundu_set/scratch/bin" "$roundu_set/scratch/$roundu_boot" "$roundu_set/scratch/logs" "$roundu_set/sim_results"
roundu_log="$roundu_set/sim_results/boot.log"
if [ "$roundu_boot" != boot ]; then roundu_log="$roundu_set/scratch/logs/$roundu_boot.log"; fi
if [ "$roundu_lint" = 1 ]; then roundu_log="$roundu_set/scratch/logs/lint.log"; fi
roundu_cleanup() {
    if [ -f "$roundu_repo/cores/roundu/ver/game/dump2bin.sh" ]; then
        mv -f "$roundu_repo/cores/roundu/ver/game/dump2bin.sh" "$roundu_set/scratch/$roundu_boot/dump2bin.sh"
    fi
}
trap roundu_cleanup EXIT
docker image inspect "$roundu_image" >/dev/null
printf 'Verilator output: %s\n' "$roundu_log"
roundu_status=0
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$roundu_repo:/jtcores" -v "$roundu_repo/modules:/jtcores/modules:ro" \
    -e ROUNDU_PRELOAD="$roundu_preload" \
    -w "/jtcores/cores/roundu/ver/roundup5/scratch/$roundu_boot" \
    "$roundu_image" -lc '
        set -euo pipefail
        export JTROOT=/jtcores JTFRAME=/jtcores/modules/jtframe
        export CORES=$JTROOT/cores MODULES=$JTROOT/modules JTBIN=$JTROOT/release
        export ROM=$JTROOT/rom RLS=$JTROOT/release MRA=$JTROOT/release/mra
        export POCKET=$JTFRAME/target/pocket
        roundu_scratch=$CORES/roundu/ver/roundup5/scratch
        export ROUNDU_VERILATOR=$(command -v verilator)
        export PATH=$roundu_scratch/bin:$JTFRAME/bin:$PATH
        export JTFRAME_REGRESSION=1 MAKEJOBS=-j4
        unset VERILATOR_ROOT
        go build -C "$JTFRAME/src/jtframe" -o "$roundu_scratch/bin/jtframe" .
        go build -C "$JTFRAME/src/jtutil" -o "$roundu_scratch/bin/jtutil" .
        cat > "$roundu_scratch/bin/verilator" <<WRAPPER
#!/bin/bash
exec "\$ROUNDU_VERILATOR" --timing -I"\$JTFRAME/hdl/cpu/nuv30" "\$@"
WRAPPER
        chmod +x "$roundu_scratch/bin/verilator"
        ln -sfn "$ROM/roundup5.rom" rom.bin
        roundu_load=(-load)
        if [ "$ROUNDU_PRELOAD" = 1 ]; then
            roundu_load=()
            dd if=rom.bin of=sdram_bank0.bin bs=1024 skip=0 count=1024 conv=swab status=none
            dd if=rom.bin of=sdram_bank1.bin bs=1024 skip=1024 count=768 conv=swab status=none
            dd if=rom.bin of=sdram_bank2.bin bs=1024 skip=1792 count=768 conv=swab status=none
            dd if=rom.bin of=sdram_bank3.bin bs=1024 skip=2560 count=320 conv=swab status=none
            dd if=/dev/zero of=sdram_bank3.bin bs=1024 seek=256 count=64 conv=notrunc status=none
        fi
        for roundu_arg in "$@"; do
            if [ "$roundu_arg" = -lint ]; then roundu_load=(); fi
        done
        jtsim -verilator -setname roundup5 -skipROM -mister "${roundu_load[@]}" -batch -fast -fx68k "$@"
    ' roundu-sim "${roundu_args[@]}" > "$roundu_log" 2>&1 || roundu_status=$?
if [ "$roundu_status" = 0 ] && [ "$roundu_lint" = 0 ] && [ "$roundu_video" = 1 ] && [ "$roundu_boot" = boot ]; then
    roundu_last=$(find "$roundu_set/scratch/boot/frames" -name 'frame_*.png' -print 2>/dev/null | sort | tail -1) || true
    if [ -n "$roundu_last" ]; then cp "$roundu_last" "$roundu_set/sim_results/boot.png"; fi
fi
exit "$roundu_status"
