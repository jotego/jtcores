#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
roundu_core=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
exec python3 "$roundu_core/ver/game/replay-video.py" "$@"
