#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 31-10-2026
set -euo pipefail

main() {
    local script_dir mame roms
    script_dir=$(cd "$(dirname "$0")" && pwd)
    mame=${MAME_BINARY:-mame}
    roms=${MAME_ROMS:-$HOME/.mame/roms}
    cd "$script_dir"
    mkdir -p logs
    # Lua checks the original ROM instructions before applying the patch.
    timeout 5m "$mame" forgottn -rompath "$roms" -video none -sound none -nothrottle \
        -skip_gameinfo -autoboot_delay 0 -autoboot_script "$script_dir/test-aim.lua" \
        -cfg_directory "$script_dir/cfg" -nvram_directory "$script_dir/nvram" \
        -seconds_to_run 60 2>&1 | tee logs/aim.log
    rg '^PASS patched boot, independent automatic aiming and neutral hold$' logs/aim.log >/dev/null
}

main "$@"
