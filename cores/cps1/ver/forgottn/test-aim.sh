#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 31-10-2026
set -euo pipefail
script_dir=$(cd "$(dirname "$0")" && pwd)
mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
roms=${MAME_ROMS:-/Users/andreabogazzi/.mame/roms-local}
version=$("$mame" -help)
[[ $version == MAME\ v0.282* ]]
cd "$script_dir"
mkdir -p logs
"$mame" forgottn -rompath "$roms" -video none -sound none -nothrottle \
    -skip_gameinfo -autoboot_delay 0 -autoboot_script "$script_dir/test-aim.lua" \
    -cfg_directory "$script_dir/cfg" -nvram_directory "$script_dir/nvram" \
    -seconds_to_run 60 2>&1 | tee logs/aim.log
rg '^PASS patched boot, two-player aiming, neutral hold and dial switch$' logs/aim.log >/dev/null
