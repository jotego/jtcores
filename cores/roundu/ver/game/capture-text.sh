#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
roundu_core=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
roundu_scene=${1:-text600-test}
case "$roundu_scene" in
    text600) roundu_frame=600; roundu_test=0 ;;
    text600-test) roundu_frame=600; roundu_test=1 ;;
    text90-test) roundu_frame=90; roundu_test=1 ;;
    *) exit 2 ;;
esac
roundu_output="$roundu_core/ver/roundup5/scenes/$roundu_scene"
mkdir -p "$roundu_output/settings"
rm -f "$roundu_output/settings/roundup5.cfg"
export ROUNDU_CAPTURE="$roundu_output"
export ROUNDU_CAPTURE_FRAME="$roundu_frame"
export ROUNDU_TEST="$roundu_test"
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
roundu_mame=${MAME_BINARY:-/Users/andreabogazzi/Emus/mame0276-arm64/mame}
roundu_rompath=${MAME_ROMPATH:-$HOME/.mame/roms-local}
python3 - "$roundu_mame" "$roundu_output" "$roundu_core/ver/game/capture_text.lua" "$roundu_rompath" "$roundu_core/ver/game/capture-text.sh" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys

binary, output, script, rompath, launcher = map(Path, sys.argv[1:])
version = subprocess.check_output([str(binary), '-help'], text=True).splitlines()[0]
if not version.startswith('MAME v0.282 '):
    raise SystemExit(f'Expected MAME 0.282, selected {version}; request the user\'s MAME 0.282 executable')
archive = next(p for ext in ['zip', '7z'] if (p := rompath / ('roundup5.' + ext)).is_file())
source = dict(binary=str(binary.resolve()), version=version,
              binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
              capture_script_sha256=hashlib.sha256(script.read_bytes()).hexdigest(),
              launcher_sha256=hashlib.sha256(launcher.read_bytes()).hexdigest(),
              rom_archive=str(archive.resolve()), rom_archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
              snapshot_view='native', snapshot_bilinear=False)
(output / 'mame-source.json').write_text(json.dumps(source, indent=2) + '\n')
PY
"$roundu_mame" roundup5 \
    -rompath "$roundu_rompath" \
    -noreadconfig -cfg_directory "$roundu_output/settings" \
    -video soft -window -sound none -nothrottle -skip_gameinfo \
    -snapview native -nosnapbilinear \
    -autoboot_script "$roundu_core/ver/game/capture_text.lua" -autoboot_delay 0 \
    -seconds_to_run 12 > "$roundu_output/mame.log" 2>&1
python3 "$roundu_core/ver/game/text_oracle.py" --scene "$roundu_scene"
