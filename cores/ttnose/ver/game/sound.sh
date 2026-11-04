#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 04-11-2026
set -euo pipefail
game_dir=$(cd "$(dirname "$0")" && pwd)
repo_dir=$(cd "$game_dir/../../../.." && pwd)
run_dir="$game_dir/../tail2nos"
mkdir -p "$run_dir/build" "$run_dir/reports/opna-game"
if [[ ${1:-} != --compare-only ]]; then
    "$game_dir/sim.sh" -load -batch -fast -video "${TTNOSE_BOOT_FRAMES:-200}" -d TTNOSE_SOUND_TRACE ../game/controls.cab >"$run_dir/build/sound-boot.log" 2>&1
fi
python3 - "$repo_dir/rom/tail2nos.rom" "$run_dir/build/opna-samples.bin" <<'PYSAMPLES'
import pathlib,sys
rom=pathlib.Path(sys.argv[1]).read_bytes()
data=rom[0x420004:0x440004]
if len(data)!=131072: raise SystemExit("Missing Tail to Nose sample ROM")
pathlib.Path(sys.argv[2]).write_bytes(data)
PYSAMPLES
YM2608_SAMPLES="$run_dir/build/opna-samples.bin" "$repo_dir/modules/jt12/ver/opna/run.sh" --trace /jtcores/cores/ttnose/ver/tail2nos/ym2608_bus.csv >"$run_dir/build/sound-compare.log" 2>&1
for name in result.json game-audio.csv game-rtl.wav game-mame.wav reference.sha256; do
    cp "$repo_dir/modules/jt12/ver/opna/reports/$name" "$run_dir/reports/opna-game/$name"
done
echo "Sound comparison: $run_dir/reports/opna-game"
