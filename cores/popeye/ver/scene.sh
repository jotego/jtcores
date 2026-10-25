#!/bin/bash
# SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
setname=${1:?Usage: scene.sh setname scene}
scene=${2:?Usage: scene.sh setname scene}
: "${JTFRAME:?Source setprj.sh first}"
: "${JOTEGO:?Set the private support directory}"
cd "$(dirname "$0")/$setname"
jtsim -load -s "$scene" -batch
# LOADROM starts captured frames after the download, so some harness versions
# have no frame_00001 and omit the automatic scene comparison. Compare the last
# complete frame explicitly in that case.
source "$JTFRAME/bin/jtsim-funcs"
SCENE="scenes/$scene/dump.bin"
candidate=$(last_frame_image || true)
if [ -n "$candidate" ]; then
    test -s "$candidate"
    cp "$candidate" "scenes/$scene/$scene.png"
fi
if compare_scene_snapshot "scenes/$scene/$scene.png"; then
    exit 0
else
    exit $?
fi
