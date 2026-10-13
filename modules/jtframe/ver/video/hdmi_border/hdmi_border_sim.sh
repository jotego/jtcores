#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
frame=../../..
pephase=${1:-7}
out=$(mktemp -d /tmp/jtframe-hdmi-XXXXXX)
iverilog -g2012 -DJTFRAME_OSD_NOLOGO -s hdmi_border_tb -o "$out/sim" hdmi_border_tb.sv \
    "$frame/hdl/video/jtframe_scan2x.v" "$frame/hdl/ram/jtframe_dual_ram.v" \
    "$frame/hdl/clocking/jtframe_sync.v" "$frame/target/mist/hdl/osd.sv"
pids=()
for phase in 319 287 383; do
    mkdir "$out/$phase"
    (cd "$out/$phase"; vvp ../sim +vphase="$phase" +pephase="$pephase" > "../phase-$phase.log"; mv hdmi_border.vcd "../phase-$phase.vcd") &
    pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid"; done
for phase in 319 287 383; do
    rg 'FRAME' "$out/phase-$phase.log"
done
echo "Logs and focused waveforms: $out"
