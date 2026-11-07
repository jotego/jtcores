#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -e

SCENE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

exec mame megazone -debug \
    -autoboot_script "$SCENE_DIR/972_flipped_2p.lua" \
    -debugscript "$SCENE_DIR/watch_regs.mame" \
    "$@"
