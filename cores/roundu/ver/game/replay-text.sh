#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
roundu_core=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
roundu_repo=$(cd "$roundu_core/../.." && pwd -P)
roundu_scene=${1:-text600-test}
case "$roundu_scene" in
    text600|text600-test|text90-test) ;;
    *) exit 2 ;;
esac
python3 "$roundu_core/ver/game/text_oracle.py" --scene "$roundu_scene"
cd "$roundu_core/ver/roundup5/scenes/$roundu_scene"
iverilog -g2012 -DSIMULATION -s text_scene_tb -o text_scene.vvp \
    "$roundu_core/ver/hdl/text_scene_tb.v" "$roundu_core/hdl/jtroundu_video.v" \
    "$roundu_core/hdl/jtroundu_text.v" "$roundu_repo/modules/jtframe/hdl/video/tilemap/"*.v \
    "$roundu_repo/modules/jtframe/hdl/ram/jtframe_dual_ram.v" \
    "$roundu_repo/modules/jtframe/hdl/ram/jtframe_dual_ram16.v" > replay-build.log 2>&1
vvp text_scene.vvp > replay.log 2>&1
python3 "$roundu_core/ver/game/text_oracle.py" --scene "$roundu_scene" --check
